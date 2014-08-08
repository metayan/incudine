;;; Copyright (c) 2013-2014 Tito Latini
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

(in-package :incudine.voicer)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (fboundp 'keynum->cps)
    ;;; Function used by default to fill the table of the frequencies (12-tET).
    (setf (symbol-function 'keynum->cps)
          (incudine.vug::create-equal-temperament 12 440 69))))

(defvar *default-midi-amplitude-array*
  ;; Linear map from velocity to amplitude.
  (coerce (loop for i below 128
                with r-midi-velocity-max = (/ 1.0 #x7f)
                collect (* i r-midi-velocity-max)) 'vector))
(declaim (type simple-vector *default-midi-amplitude-array*))

;;; Function used by default to fill the table of the amplitudes.
(declaim (inline velocity->amp))
(defun velocity->amp (velocity)
  (declare (type (integer 0 127) velocity))
  (svref *default-midi-amplitude-array* velocity))

(defstruct (midi-event (:include event) (:copier nil))
  (channel 0 :type (integer 0 15))
  (lokey 0 :type (integer 0 127))
  (hikey 127 :type (integer 0 127))
  ;; Table of the frequencies.
  (freq-vector (make-array 128) :type (simple-vector 128))
  ;; Table of the amplitudes.
  (amp-vector (make-array 128) :type (simple-vector 128))
  ;; Ignore the note-off message if NOTE-OFF-P is NIL.
  (note-off-p t :type boolean))

(defmethod print-object ((obj midi-event) stream)
  (format stream "#<MIDI-EVENT :VOICER ~A~%~13t:RESPONDER ~A>"
          (event-voicer obj) (event-responder obj)))

(declaim (inline fill-amp-vector))
(defun fill-amp-vector (function midi-event)
  (declare (type function function) (type midi-event midi-event))
  (dotimes (i 128 midi-event)
    (setf (svref (midi-event-amp-vector midi-event) i)
          (funcall function i))))

(declaim (inline fill-freq-vector))
(defun fill-freq-vector (function midi-event)
  (declare (type function function) (type midi-event midi-event))
  (dotimes (i 128 midi-event)
    (setf (svref (midi-event-freq-vector midi-event) i)
          (funcall function i))))

(declaim (inline update-freq-vector))
(defun update-freq-vector (midi-event)
  (declare (type midi-event midi-event))
  (fill-freq-vector (event-freq-function midi-event) midi-event))

(declaim (inline update-amp-vector))
(defun update-amp-vector (midi-event)
  (declare (type midi-event midi-event))
  (fill-amp-vector (lambda (vel)
                     (* (funcall (event-amp-function midi-event) vel)
                        (event-amp-mult midi-event)))
                   midi-event))

;;; If NOTE-OFF-P is T, a note-on message (status byte 9) with velocity 0
;;; is interpreted as a note-off message.
(defmacro responder-noteon-form ((voicer note-off-p keynum velocity) &body body)
  (if note-off-p
      `(if (plusp ,velocity)
           (progn ,@body)
           (unsafe-release ,voicer ,keynum))
      `(progn ,@body)))

(defmacro midi-bind (voicer stream &key (channel 0) (lokey 0) (hikey 127)
                     (freq-keyword :freq) (freq-function #'keynum->cps)
                     (amp-keyword :amp) (amp-mult 0.2)
                     (amp-function #'velocity->amp) (gate-keyword :gate)
                     (gate-value 1) (note-off-p t))
  (with-gensyms (event status data1 data2 typ)
    `(let ((,event (make-midi-event :voicer ,voicer :channel ,channel
                     :lokey ,lokey :hikey ,hikey :freq-keyword ,freq-keyword
                     :freq-function ,freq-function :amp-keyword ,amp-keyword
                     :amp-mult ,amp-mult :amp-function ,amp-function
                     :gate-keyword ,gate-keyword :gate-value ,gate-value
                     :note-off-p ,note-off-p)))
       (update-freq-vector (update-amp-vector ,event))
       (setf (event-responder ,event)
             (incudine:make-responder ,stream
                (lambda (,status ,data1 ,data2)
                  (declare #.*standard-optimize-settings*
                           (type (integer 0 255) ,status)
                           (type (integer 0 127) ,data1 ,data2))
                  (when (and (= (ldb (byte 4 0) ,status) ,channel)
                             (<= ,lokey ,data1)
                             (<= ,data1 ,hikey))
                    (let ((,typ (ldb (byte 4 4) ,status)))
                      (cond
                        ((= ,typ 9)
                         (with-safe-change (,voicer)
                           (responder-noteon-form (,voicer ,note-off-p ,data1
                                                   ,data2)
                             (unsafe-set-controls ,voicer
                               ,@(if freq-keyword
                                     `(,freq-keyword
                                       (the single-float
                                         (svref (midi-event-freq-vector ,event)
                                                ,data1))))
                               ,@(if amp-keyword
                                     `(,amp-keyword
                                       (the single-float
                                         (svref (midi-event-amp-vector ,event)
                                                ,data2))))
                               ,@(if gate-keyword
                                     `(,gate-keyword ,gate-value)))
                             (unsafe-trigger ,voicer ,data1))))
                        ,@(if note-off-p
                              `(((= ,typ 8) (release ,voicer ,data1))))))))))
       ,event)))

(defun scale-midi-amp (midi-event mult)
  (declare (type midi-event midi-event) (type real mult))
  (setf (event-amp-mult midi-event) mult)
  (update-amp-vector midi-event)
  mult)

(defun set-midi-freq-function (midi-event function)
  (declare (type midi-event midi-event) (type function function))
  (setf (event-freq-function midi-event) function)
  (update-freq-vector midi-event)
  function)

(defun set-midi-amp-function (midi-event function)
  (declare (type midi-event midi-event) (type function function))
  (setf (event-amp-function midi-event) function)
  (update-amp-vector midi-event)
  function)
