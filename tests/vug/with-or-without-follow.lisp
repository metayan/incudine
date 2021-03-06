(in-package :incudine-tests)

(enable-sharp-square-bracket-syntax)

(dsp! with-follow-test-1 (freq amp)
  (with-follow (freq)
    (setf amp (sample (if (< freq 500) .5 .2))))
  (out (sine freq amp 0)))

(dsp! with-follow-test-2 (freq amp)
  (initialize (with-follow (freq)
                (setf amp (sample (if (< freq 500) .5 .2)))))
  (out (sine freq amp 0)))

(dsp! with-follow-test-3 (freq amp)
  (with-samples ((g (with-follow (freq)
                      (setf amp (sample (if (< freq 500) .5 .2))))))
    (out (sine freq g 0))))

(dsp! with-follow-test-4 (freq p)
  (with ((phs (phasor freq 0))
         (last +sample-zero+)
         (changed nil))
    (declare (sample phs last) (boolean changed))
    (initialize (setf last phs))
    (with-follow (p)
      ;; PHS is performance-time
      (setf phs p)
      (setf changed t)
      phs)
    (if changed
        ;; PHS is the value of the updated parameter P
        (setf changed nil)
        (maybe-expand phs))
    (out phs)
    (setf last phs)))

(dsp! without-follow-test-1 (freq amp)
  (with-samples ((g (without-follow (amp)
                      (setf amp (sample (if (< freq 500) .5 .2))))))
    (out (sine freq g 0))))

(dsp! without-follow-test-2 ((n fixnum))
  (with ((frm (without-follow (n)
                ;; Expansion with other initializations
                ;; where the VUG-VARIABLES don't depend
                ;; on the control parameter N.
                (make-frame (+ n 2))))
         (scl (/ (sample 1) n)))
    (declare (type frame frm) (type sample scl))
    ;; Side effect: WITH-CONTROL-PERIOD changes the control parameter N.
    (with-control-period (n)
      (setf (smp-ref frm)
            (* (if (> n 200) -1 1) (sample n))))
    (out (* scl (smp-ref frm)))))

(dsp! without-follow-test-3 (a b c scl)
  (vuglet ((don (x)
             ;; Explicit WITH-FOLLOW because this local VUG
             ;; is used within the body of WITHOUT-FOLLOW.
             (with-samples ((y (with-follow (b)
                                 (* x (+ a b c)))))
               (+ y y))))
    (with-samples ((din (without-follow (a b)
                          ;; DIN follows the control parameter C,
                          ;; DON follows the control parameters B and C.
                          (don (* a (- c b))))))
      (out (* scl din)))))

(with-dsp-test (with-follow.1
      :md5 #(26 199 222 9 34 233 149 188 155 219 178 3 28 169 246 245))
  (with-follow-test-1 440 .3 :id 123)
  (at #[1 s] #'set-control 123 :freq 200)
  (at #[3/2 s] #'set-control 123 :amp .3)
  (at #[2 s] #'set-control 123 :freq 1000)
  (at #[5/2 s] #'set-control 123 :amp .3))

(with-dsp-test (with-follow.2
      :md5 #(195 2 44 223 119 114 205 47 0 113 86 210 58 123 8 170))
  (with-follow-test-2 440 .3 :id 123)       ; initial AMP is not .3 but .5
  (at #[1 s] #'set-control 123 :freq 200)
  (at #[3/2 s] #'set-control 123 :amp .3)
  (at #[2 s] #'set-control 123 :freq 1000)
  (at #[5/2 s] #'set-control 123 :amp .3))

(with-dsp-test (with-follow.3
      :md5 #(214 105 172 97 50 65 114 30 82 17 111 17 82 152 84 255))
  (with-follow-test-3 440 .3 :id 123)
  (at #[1 s] #'set-control 123 :freq 200)
  (at #[3/2 s] #'set-control 123 :amp .3)   ; ignored
  (at #[2 s] #'set-control 123 :freq 1000)
  (at #[5/2 s] #'set-control 123 :amp .3))  ; ignored

(with-dsp-test (with-follow.4
      :md5 #(109 114 43 224 128 31 1 241 225 44 190 182 169 167 58 136))
  (with-follow-test-4 1 .5 :id 1)
  (at #[1.5 s] #'set-control 1 :p .15))

(with-dsp-test (without-follow.1
      :md5 #(214 105 172 97 50 65 114 30 82 17 111 17 82 152 84 255))
  (without-follow-test-1 440 .3 :id 123)
  (at #[1 s] #'set-control 123 :freq 200)
  (at #[3/2 s] #'set-control 123 :amp .3)   ; ignored
  (at #[2 s] #'set-control 123 :freq 1000)
  (at #[5/2 s] #'set-control 123 :amp .3))  ; ignored

(with-dsp-test (without-follow.2
      :md5 #(23 230 169 179 79 83 199 145 147 186 71 102 22 50 150 218))
  (without-follow-test-2 128 :id 123)
  (at #[5/2 s] #'set-control 123 :n 256))

(with-dsp-test (without-follow.3
      :md5 #(150 111 196 218 12 176 249 242 93 165 222 184 223 183 64 121))
  (without-follow-test-3 1 2 3 1/30 :id 123)
  ;; Ignored.
  (at #[1 s] #'set-control 123 :a 100)
  ;; (* 2 scl old-x (+ a b c))
  (at #[2 s] #'set-controls 123 :a 3 :b 5/2)
  ;; (* 2 scl (* a (- c b)) (+ a b c))
  (at #[3 s] #'set-control 123 :c 3))
