;;; Copyright (c) 2013-2020 Tito Latini
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

(in-package :incudine)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *after-gc-fn* (lambda () (nrt-msg debug "gc happened")))

  (incudine.util::add-after-gc-hook *after-gc-fn*)

  ;;; In JACK2, `sem_timedwait' is interrupted by SIGUSR2 during the
  ;;; gc and it is notified with a message to the standard error.
  ;;; The default is to hide these messages.
  #+jack-audio
  (pushnew #'incudine.external::silent-jack-errors *initialize-hook*))

(defmacro with-new-thread ((varname name priority debug-message) &body body)
  `(unless ,varname
     (setf ,varname
           (bt:make-thread
             (lambda ()
               (setf (thread-priority (bt:current-thread)) ,priority)
               ,@body)
             :name ,name))
     (msg debug ,debug-message)))

(defun nrt-start ()
  (with-new-thread (*nrt-thread* "audio-nrt-thread" *nrt-priority*
                    "non-realtime thread started")
    (loop (sync-condition-wait *nrt-audio-sync*)
          (fifo-perform-functions *from-engine-fifo*)))
  (with-new-thread (*fast-nrt-thread* "audio-fast-nrt-thread"
                    *fast-nrt-priority* "fast non-realtime thread started")
    (loop (sync-condition-wait *fast-nrt-audio-sync*)
          (fifo-perform-functions *fast-from-engine-fifo*)
          (fast-nrt-perform-functions)))
  (and *nrt-thread* *fast-nrt-thread*))

(defun nrt-stop ()
  (when *nrt-thread*
    (bt:destroy-thread *nrt-thread*)
    (bt:destroy-thread *fast-nrt-thread*)
    (loop while (bt:thread-alive-p *nrt-thread*))
    (msg debug "non-realtime thread stopped")
    (loop while (bt:thread-alive-p *fast-nrt-thread*))
    (msg debug "fast non-realtime thread stopped")
    (setf *nrt-thread* nil *fast-nrt-thread* nil)))

(defvar *foreign-client-name* (cffi:null-pointer))

#-dummy-audio
(defun rt-thread-callback (loop-function)
  (declare (type function loop-function))
  #+portaudio (incudine.external::pa-set-devices
                incudine.config::*portaudio-output-device*
                incudine.config::*portaudio-input-device*)
  (cond ((and (zerop (rt-audio-init *number-of-input-bus-channels*
                                    *number-of-output-bus-channels*
                                    (rt-params-frames-per-buffer *rt-params*)
                                    *foreign-client-name*
                                    *sample-counter*))
              (zerop (rt-audio-start)))
         (let ((buffer-size (rt-buffer-size)))
           (setf (rt-params-frames-per-buffer *rt-params*) buffer-size)
           (set-sample-rate (rt-sample-rate))
           #+jack-midi (nrt-funcall #'jackmidi::update-streams)
           (funcall loop-function buffer-size)))
        (t (setf *rt-thread* nil)
           (msg error (rt-get-error-msg))
           (rt-stop))))

#+dummy-audio
(defun rt-thread-callback (loop-function)
  (declare (ignore loop-function))
  (msg warn "using dummy audio driver; you could change the realtime callback"))

(defun make-rt-thread (name function args)
  (declare (type function function))
  (with-new-thread (*rt-thread* name (rt-params-priority *rt-params*)
                    "realtime thread started")
    (call-hooks "rt-thread-start" *rt-thread-start-hook* :on-error :warn)
    (apply function args)
    (call-hooks "rt-thread-exit" *rt-thread-exit-hook* :on-error :warn)))

(defun destroy-rt-thread ()
  (when (and *rt-thread* (bt:thread-alive-p *rt-thread*))
    (bt:destroy-thread *rt-thread*)))

(defun get-foreign-client-name ()
  (cffi:foreign-string-to-lisp *foreign-client-name*))

(defun set-foreign-client-name (name &optional (max-size 64))
  (unless (and (not (null-pointer-p *foreign-client-name*))
               (string-equal (get-foreign-client-name) *client-name*))
    (unless (null-pointer-p *foreign-client-name*)
      (cffi:foreign-free *foreign-client-name*))
    (setf *foreign-client-name*
          (cffi:foreign-string-alloc name :end (min (length name) max-size))))
  name)

(defmacro compute-tick (&optional (update-peak-p t))
  (with-gensyms (funcons flist fn dummy-fn c n chan)
    `(let ((,funcons (node-funcons *root-node*)))
       (do ((,flist ,funcons (cdr ,flist)))
           ((null ,flist))
         (declare (type list ,flist))
         (let ((,fn (car ,flist)))
           (declare (type function ,fn))
           (handler-case (funcall ,fn)
             (condition (,c)
               ;; Set a dummy function and free the node at the next tick
               (let ((,dummy-fn (lambda (ch) (declare (ignore ch)))))
                 (setf (car ,flist) ,dummy-fn ,fn ,dummy-fn)
                 (dograph (,n)
                   (unless (group-p ,n)
                     (when (eq (car (node-funcons ,n)) ,dummy-fn)
                       (node-free ,n))))
                 (nrt-msg error "~A" ,c))))))
       ,(if update-peak-p
            `(when ,funcons
               (dochannels (,chan *number-of-output-bus-channels*)
                 (update-peak-values ,chan)))))))

(defun maybe-porttime-start ()
  (when (and incudine.config::*enable-portmidi-output-sample-offset*
             (funcall (find-symbol "STARTED" "PORTTIME")))
    (setf (smp-ref *portmidi-time* 0)
          (sample (the (unsigned-byte 32)
                       (funcall (find-symbol "TIME" "PORTTIME")))))
    t))

(defun rt-audio-cycle (frames block-size &key recover-p)
  (declare (type non-negative-fixnum frames block-size))
  (let ((pt-started-p (unless recover-p (maybe-porttime-start))))
    #+jack-midi
    (if recover-p
        (jackmidi::read-cached-inputs frames)
        (progn
          (jackmidi::process frames)
          (jackmidi::write-cached-outputs)))
    (fifo-perform-functions *to-engine-fifo*)
    (free-dirty-nodes)
    (do ((i 0 (+ i block-size)))
        ((>= i frames))
      (declare (type non-negative-fixnum i))
      (fifo-perform-functions *fast-to-engine-fifo*)
      (incudine.edf:sched-loop)
      (compute-tick)
      (inc-io-pointers block-size)
      (when (and pt-started-p (not recover-p))
        (inc-portmidi-time incudine.util::*sample-duration-msec*))
      (incf-sample-counter block-size))))

;;; Continue the audio cycle started from C-thread during gc.
(defun continue-last-audio-cycle (frames block-size)
  (reset-io-pointers)
  (incudine.external::rt-continue-cycle-begin frames)
  (rt-audio-cycle frames block-size)
  (rt-cycle-end frames))

;;; Recovery of audio cycles suspended during gc by processing the
;;; cached audio and MIDI inputs (audio outputs are ignored).
(defun recover-suspended-audio-cycles (frames block-size)
  (declare (type non-negative-fixnum frames block-size))
  (maybe-porttime-start)
  (loop for i of-type fixnum from 0
        while (incudine.external::rt-cached-inputs-p) do
          (reset-io-pointers)
          (incudine.external::rt-inputs-from-cache-begin)
          (rt-audio-cycle frames block-size :recover-p t)
          (incudine.external::rt-inputs-from-cache-end)
        finally (nrt-msg debug "~D suspended audio cycles" i)))

(defvar *recover-suspended-audio-cycles-p*
  (incudine.external::set-foreign-rt-thread-callback
    (and (boundp 'incudine.config::*recover-suspended-audio-cycles-p*)
         incudine.config::*recover-suspended-audio-cycles-p*)))
(declaim (type boolean *recover-suspended-audio-cycles-p*))

(defun recover-suspended-audio-cycles-p ()
  "Whether the audio cycles suspended during gc are recovered by processing
the cached audio inputs and MIDI events (audio outputs are ignored). Setfable.

If NIL, the time is not incremented after gc, therefore the old scheduled
functions are delayed by the garbage collection time.

The default is the value of the configuration variable
*RECOVER-SUSPENDED-AUDIO-CYCLES-P*, or NIL if that variable is not set."
*recover-suspended-audio-cycles-p*)

(defun set-recover-suspended-audio-cycles-p (value)
  (declare (type boolean value))
  (unless (eq (rt-status) :stopped)
    (rt-stop)
    (msg warn "rt-thread stopped."))
  (unless (eq *recover-suspended-audio-cycles-p* value)
    (setf *recover-suspended-audio-cycles-p* value))
  (incudine.external::set-foreign-rt-thread-callback value))

(defsetf recover-suspended-audio-cycles-p set-recover-suspended-audio-cycles-p)

(defun abort-recovery-audio-cycles (frames block-size)
  (continue-last-audio-cycle frames block-size)
  (nrt-msg warn "slow recovery of audio cycles during gc... aborting"))

(define-constant +recovery-cycles-restart-limit+ 2)

(defglobal rt-state nil)
(declaim (type boolean rt-state))

#-dummy-audio
(defmacro with-restart-point ((label frames block-size) &body body)
  (with-gensyms (recovery-cycles-restart)
    `(let ((,recovery-cycles-restart 0))
       (declare (fixnum ,recovery-cycles-restart))
       (tagbody
           ;; Lisp restarts from here after the stop caused by the gc.
           ,label
             (when rt-state
               (when (recover-suspended-audio-cycles-p)
                 (recover-suspended-audio-cycles ,frames ,block-size))
               (rt-set-busy-state nil)
               (rt-condition-wait)
               (when (recover-suspended-audio-cycles-p)
                 (incudine.util::without-gcing
                   (when (incudine.external::rt-cached-inputs-p)
                     (cond ((incudine.external::rt-last-cycle-p)
                            ;; Continue the audio cycle started from C-thread.
                            (continue-last-audio-cycle ,frames ,block-size)
                            ;; Another gc here should be rare.
                            (incudine.util::with-stop-for-gc-pending
                              (incudine.external::rt-clear-cached-inputs)
                              #+jack-midi (jackmidi::clear-cached-events)
                              (rt-transfer-to-c-thread)
                              (go ,label)))
                           (t
                            (when (< ,recovery-cycles-restart
                                     ,+recovery-cycles-restart-limit+)
                              (incf ,recovery-cycles-restart)
                              ;; There are other suspended cycles to recover.
                              ;; The current cycle continues from C-thread.
                              (rt-transfer-to-c-thread)
                              (go ,label))
                            ;; Slow recovery tested with high latency setting
                            ;; in PortAudio.
                            (abort-recovery-audio-cycles ,frames ,block-size))))
                   ;; Buffer indexes zero.
                   (incudine.external::rt-clear-cached-inputs)
                   #+jack-midi (jackmidi::clear-cached-events))))
          ,@body))))

#-dummy-audio
(defmacro with-rt-cycle ((reset-label frames-var) &body body)
  (declare (ignorable frames-var))
  `(incudine.util::without-gcing
     (setf ,frames-var (rt-cycle-begin))
     (incudine.util::with-stop-for-gc-pending
       (when (recover-suspended-audio-cycles-p)
         (incudine.external::rt-cache-inputs))
       (setf ,frames-var 0))
     ,@body
     (incudine.util::without-float-overflow-trap
       (rt-cycle-end ,frames-var))
     (incudine.util::with-stop-for-gc-pending
       ;; No xruns, jack knows that lisp is busy.
       ;; The output buffer is filled with zeroes.
       (rt-transfer-to-c-thread)
       (go ,reset-label))))

(defvar *block-size* (if (boundp 'incudine.config::*rt-block-size*)
                         incudine.config::*rt-block-size*
                         1))
(declaim (type positive-fixnum *block-size*))

(defvar *block-input-samples* (* *block-size* *number-of-input-bus-channels*))
(declaim (type non-negative-fixnum *block-input-samples*))

(defvar *block-output-samples* (* *block-size* *number-of-output-bus-channels*))
(declaim (type non-negative-fixnum *block-output-samples*))

(declaim (inline block-size))
(defun block-size ()
  "Return the block size."
  *block-size*)

#-dummy-audio
(defmacro rt-loop-form (frames-per-buffer block-size)
  (with-gensyms (frames reset pt-started pm-time-delta)
    (declare (ignorable pt-started pm-time-delta))
    `(block nil
       (rt-set-io-buffers *%input-pointer* *%output-pointer*)
       (unless (= ,block-size 1)
         (reduce-warnings
           (when (plusp (rem ,frames-per-buffer ,block-size))
             (msg warn
                  "Block size ~D is not a multiple of ~D (frames per buffer)"
                  ,block-size ,frames-per-buffer)
             (call-after-stop)
             (return-from nil))))
       (setf *block-size* ,block-size)
       (setf *block-input-samples* (* *block-size* *number-of-input-bus-channels*))
       (setf *block-output-samples* (* *block-size* *number-of-output-bus-channels*))
       (setf rt-state t)
       (reset-sample-counter)
       (let ((,frames ,frames-per-buffer)
             ,@(when incudine.config::*enable-portmidi-output-sample-offset*
                 `((,pt-started (pt:started))
                   (,pm-time-delta incudine.util::*sample-duration-msec*))))
         (declare (type non-negative-fixnum ,frames)
                  ,@(when incudine.config::*enable-portmidi-output-sample-offset*
                      `((type boolean ,pt-started)
                        (type sample ,pm-time-delta))))
         (with-restart-point (,reset ,frames-per-buffer ,block-size)
           (loop while rt-state do
                (reset-io-pointers)
                (with-rt-cycle (,reset ,frames)
                  ,@(when incudine.config::*enable-portmidi-output-sample-offset*
                      `((when ,pt-started
                          (setf (smp-ref *portmidi-time* 0)
                                (sample (the (unsigned-byte 32) (pt:time)))))))
                  #+jack-midi (jackmidi::process ,frames)
                  (fifo-perform-functions *to-engine-fifo*)
                  (free-dirty-nodes)
                  (do ((i 0 (+ i ,block-size)))
                      ((>= i ,frames))
                    (declare (type non-negative-fixnum i))
                    (fifo-perform-functions *fast-to-engine-fifo*)
                    (incudine.edf:sched-loop)
                    (compute-tick)
                    (inc-io-pointers ,block-size)
                    ,@(when incudine.config::*enable-portmidi-output-sample-offset*
                        `((when ,pt-started
                            (inc-portmidi-time ,pm-time-delta))))
                    (incf-sample-counter ,block-size))))
           (rt-transfer-to-c-thread)
           (nrt-funcall #'rt-stop))))))

;;; Real-time loop callback for sample by sample computation.
#-dummy-audio
(defun rt-loop-1 (frames-per-buffer)
  (declare #.*standard-optimize-settings*
           (type non-negative-fixnum frames-per-buffer))
  (rt-loop-form frames-per-buffer 1))

;;; Real-time loop callback with a block size of 64 frames.
#-dummy-audio
(defun rt-loop-64 (frames-per-buffer)
  (declare #.*standard-optimize-settings*
           (type non-negative-fixnum frames-per-buffer))
  (rt-loop-form frames-per-buffer 64))

#-dummy-audio
(defmacro rt-loop-callback (block-size)
  "Return a real-time loop callback with an arbitrary BLOCK-SIZE."
  (with-gensyms (%block-size)
    `(lambda (frames-per-buffer)
       (declare #.*standard-optimize-settings*
                (type non-negative-fixnum frames-per-buffer))
       (let ((,%block-size ,block-size))
         (declare (type non-negative-fixnum ,%block-size))
         (rt-loop-form frames-per-buffer ,%block-size)))))

(defun rt-preamble ()
  (nrt-start)
  #-dummy-audio
  (set-foreign-client-name *client-name*)
  (values))

#-dummy-audio
(defun after-rt-stop ()
  (unless (zerop (rt-audio-stop))
    (msg error (rt-get-error-msg)))
  #+jack-midi (jackmidi::reset)
  (values))

(defparameter *default-rt-loop-cb*
  #+dummy-audio #'identity
  #-dummy-audio
  (if (and (boundp 'incudine.config::*rt-block-size*)
           (> incudine.config::*rt-block-size* 1))
      (if (= incudine.config::*rt-block-size* 64)
          #'rt-loop-64
          (eval `(rt-loop-callback ,incudine.config::*rt-block-size*)))
      #'rt-loop-1))
(declaim (type function *default-rt-loop-cb*))

#-dummy-audio
(defun %set-rt-block-size (value rt-loop-n-fn)
  (declare (type positive-fixnum value) (type (or function null) rt-loop-n-fn))
  (unless (eq (rt-status) :stopped)
    (rt-stop)
    (msg warn "rt-thread stopped."))
  (setf *default-rt-loop-cb*
        (case value
          (1 #'rt-loop-1)
          (64 #'rt-loop-64)
          (otherwise (or rt-loop-n-fn #'rt-loop-64))))
  (setf *block-input-samples* (* value *number-of-input-bus-channels*))
  (setf *block-output-samples* (* value *number-of-output-bus-channels*))
  (msg debug "set realtime block size to ~D" value)
  (setf *block-size* value)
  (incudine::call-hooks "set-rt-block-size" incudine.util:*block-size-hook*)
  value)

#-dummy-audio
(defmacro set-rt-block-size (value)
  "Change the block size, update the default realtime loop callback
and run the hook INCUDINE.UTIL:*BLOCK-SIZE-HOOK*.

This setting stops the real-time thread."
  `(%set-rt-block-size ,value ,(unless (member value '(1 64))
                                 `(rt-loop-callback ,value))))

(defvar *after-rt-stop-function* nil)
(declaim (type (or function null) *after-rt-stop-function*))

(defvar *threads-with-altered-affinity* (make-hash-table))
(declaim (type hash-table *threads-with-altered-affinity*))

(defun set-rt-cpu (n)
  (declare (type non-negative-fixnum n))
  (unset-rt-cpu)
  (if *rt-thread*
      (let ((mask (ash 1 n)))
        (dolist (thr (bt:all-threads))
          (if (eq thr *rt-thread*)
              (setf (thread-affinity thr) mask)
              (setf (gethash thr *threads-with-altered-affinity*)
                    (setf (thread-affinity thr)
                          (logandc2 (thread-affinity thr) mask)))))
        n)
      (incudine-error "real-time thread not started")))

(defun unset-rt-cpu ()
  (when (plusp (hash-table-count *threads-with-altered-affinity*))
    (when *rt-thread*
      (let ((n (thread-affinity *rt-thread*)))
        (declare (type non-negative-fixnum n))
        (if (power-of-two-p n)
            ;; Revert the unchanged thread affinities.
            (maphash (lambda (thr mask)
                       (when (and (bt:thread-alive-p thr)
                                  (= (thread-affinity thr) mask))
                         (setf (thread-affinity thr) (logior mask n))))
                     *threads-with-altered-affinity*)
            (msg warn "rt-thread affinity altered"))))
    (clrhash *threads-with-altered-affinity*)
    nil))

(defun rt-cpu ()
  "Return the zero-based number of CPU reserved for the real-time thread.
Setfable."
  (if *rt-thread*
      (let ((n (thread-affinity *rt-thread*)))
        (if (power-of-two-p n)
            (1- (integer-length n))
            (incudine-error "real-time thread without a reserved CPU.")))
      (incudine-error "real-time thread not started")))

(defsetf rt-cpu set-rt-cpu)

(defun rt-start (&key (cpu incudine.config:*rt-cpu*)
                 (preamble-function #'rt-preamble)
                 (thread-name "audio-rt-thread")
                 (thread-function #'rt-thread-callback)
                 (thread-function-args (list #-dummy-audio
                                             *default-rt-loop-cb*
                                             #+dummy-audio nil))
                 (after-stop-function #-dummy-audio #'after-rt-stop
                                      #+dummy-audio nil)
                 (gc-p t))
  "Create the real-time thread named THREAD-NAME and return :STARTED
if no error has occured.

Call INIT to initialize Incudine if necessary.

If CPU is non-NIL, it is the zero-based number of CPU reserved for the
real-time thread. The thread affinities of the other threads are
reverted during RT-STOP if they are unchanged in the meanwhile.

CPU defaults to the configuration variable *RT-CPU*.

PREAMBLE-FUNCTION is called before to create the thread. By default
it starts the auxiliary non-real-time threads and set the client name.

THREAD-NAME defaults to \"audio-rt-thread\".

THREAD-FUNCTION is called on the arguments THREAD-FUNCTION-ARGS for
the initialisation and to call the real-time loop callback.

AFTER-STOP-FUNCTION is called by RT-STOP and it terminates the audio loop
by default.

If GC-P is T (default), initiate a garbage collection before to create
the thread."
  (declare (type (or null non-negative-fixnum) cpu)
           (type string thread-name)
           (type (or function null) preamble-function after-stop-function)
           (type function thread-function)
           (type cons thread-function-args)
           (type boolean gc-p))
  (unless *rt-thread*
    (init)
    (setf *after-rt-stop-function* after-stop-function)
    (when preamble-function (funcall preamble-function))
    (when gc-p (incudine.util::gc :full t))
    (make-rt-thread thread-name thread-function thread-function-args)
    (sleep .1)
    (setf (rt-params-status *rt-params*)
          (cond ((and *rt-thread* (bt:thread-alive-p *rt-thread*))
                 (when cpu (set-rt-cpu cpu))
                 :started)
                (t (msg warn "failed to start the realtime thread")
                   (setf *rt-thread* nil)
                   (setf *after-rt-stop-function* nil)
                   :stopped)))))

(defun rt-status ()
  "Real-time thread status. Return :STARTED or :STOPPED."
  (rt-params-status *rt-params*))

(defun call-after-stop ()
  (nrt-funcall (lambda ()
                 (when *after-rt-stop-function*
                   (funcall *after-rt-stop-function*)
                   (setf *after-rt-stop-function* nil)
                   (msg debug "after realtime stop")))))

(defun rt-stop ()
  "Stop the real-time thread and return :STOPPED."
  (unless (eq (rt-status) :stopped)
    (cond ((rt-thread-p) (nrt-funcall #'rt-stop))
          (t
           (when *rt-thread*
             (let ((thread *rt-thread*))
               (unset-rt-cpu)
               (setf *rt-thread* nil)
               (setf rt-state nil)
               (sleep .05)
               (loop while (bt:thread-alive-p thread))
               (msg debug "realtime thread stopped")))
           (call-after-stop)
           (setf (rt-params-status *rt-params*) :stopped)))))

#+portaudio
(defun portaudio-set-device (output &optional (input output))
  "Set the index of the audio device.

If INPUT is non-NIL, the indexes of the output and input devices are
OUTPUT and INPUT respectively.

This setting stops the real-time thread.

See PORTAUDIO-DEVICE-INFO."
  (declare (type fixnum output input))
  (unless (and (= incudine.config::*portaudio-output-device* output)
               (= incudine.config::*portaudio-input-device* input))
    (unless (eq (rt-status) :stopped)
      (rt-stop)
      (msg warn "rt-thread stopped."))
    (setf incudine.config::*portaudio-output-device* output
          incudine.config::*portaudio-input-device* input))
  (values output input))

#-dummy-audio
(setf
  (documentation 'rt-buffer-size 'function)
  "Return the number of frames passed to the real-time callback function."
  (documentation 'rt-sample-rate 'function)
  "Return the sample rate of the real-time audio system."
  (documentation 'rt-time-offset 'function)
  "Return the time from the start of the current real-time process cycle.

TIME-UNIT is FRAMES or SECONDS (default).

Example:

    ;;; How to fix a relative OSC time in real-time thread.

    (in-package :scratch)

    (rt-start)

    (defvar *oscout* (osc:open :direction :output))

    (defun osc-test (time)
      (let ((os (rt-time-offset)))
        ;; osc-time is (+ (timestamp) os .3)
        (osc:simple-bundle *oscout* (+ os .3) \"/time/test\" \"d\" os)
        (aat (+ time #[1/3 s]) #'osc-test it)
        (nrt-msg info \"~A\" os)))

    (setf (logger-level) :info)
    (rt-eval () (osc-test (now)))

    (flush-pending)
    (rt-stop)"
  (documentation 'incudine.external:rt-cycle-start-time 'function)
  "Return the time in samples of the start of the current real-time
process cycle."
  (documentation 'incudine.external:rt-client 'function)
  "Return the foreign pointer to the JACK client or PortAudio stream.")
