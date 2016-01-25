(in-package :incudine-tests)

(deftest quantize-real-real.1
    (values (quantize 123.45 5.25)
            (quantize 97.5 5))
  126.0 100)

(deftest quantize-real-sv.1
    (flet ((test (sv)
             (mapcar (lambda (x) (quantize x sv))
                     '(100 141 155 168 171 200 250 280
                       300 350 400 450 470 486 500 559
                       600 650 700 720.12345 750.05 800
                       900 950 1000 1100 10000))))
      (let ((sv #(107 138 149 176 273 274 286 461
                  478 492 553 721 755 944 996 1039)))
        (values (test sv)
                (test (subseq sv 0 15))
                (test (subseq sv 1 15))
                (test (subseq sv 1 14))
                (test (subseq sv 2 14))
                (test (subseq sv 2 13))
                (test (subseq sv 3 13))
                (test (subseq sv 3 12)))))
  (107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 1039 1039)
  (107 138 149 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 996 996)
  (138 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 996 996)
  (138 138 149 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 944 944 944)
  (149 149 149 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 944 944 944)
  (149 149 149 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 755 755 755 755 755)
  (176 176 176 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 755 755 755 755 755)
  (176 176 176 176 176 176 273 274 286 286 461 461 478 492 492 553 553 721 721
   721 721 721 721 721 721 721 721))

(deftest quantize-real-sv.2
    (flet ((test (sv)
             (mapcar (lambda (x) (quantize x sv))
                     '(50 100 150 250 280 301 399
                       401 450 500 600 580 600 1000))))
      (let ((sv #(100 100 100 200 200 300 300 300
                  300 400 400 500 600 600 600 600)))
        (values (test sv)
                (test (subseq sv 0 15))
                (test (subseq sv 1 15))
                (test (subseq sv 1 14))
                (test (subseq sv 2 14))
                (test (subseq sv 2 13))
                (test (subseq sv 3 13))
                (test (subseq sv 3 12)))))
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600)
  (200 200 200 300 300 300 400 400 500 500 600 600 600 600)
  (200 200 200 300 300 300 400 400 500 500 500 500 500 500))

(deftest quantize-sv-real.1
    (let ((sv (vector 11 23 19 123.456 31 49 999.999)))
      (flet ((test (from)
               (coerce (quantize sv from) 'list)))
        (values (test .75) (test .5) (test 3) (test 7))))
  (11.25 23.25 18.75 123.75 30.75 48.75 999.75)
  (11.0 23.0 19.0 124.0 31.0 49.0 1000.0)
  (12 24 18 123 30 48 999)
  (14 21 21 126 28 49 1001))

(deftest quantize-sv-real.2
    (let ((sv (vector 11 23 19 123.456 31 49 999.999)))
      (flet ((test (from)
               (coerce (quantize sv from :start 2 :end 5
                                 :filter-function (lambda (i x)
                                                    (declare (ignore i))
                                                    (truncate x .1)))
                       'list)))
        (values (test .75) (test .5) (test 3) (test 7))))
  (11 23 187 1237 307 49 999.999)
  (11 23 1870 12370 3070 49 999.999)
  (11 23 18690 123690 30690 49 999.999)
  (11 23 186900 1236900 306880 49 999.999))

(deftest quantize-sv-sv.1
    (quantize #(100 141 155 168 171 200 250 280 300 350 400 450 470 486 500
                559 600 650 700 720.12345 750.05 800 900 950 1000 1100 10000)
              #(107 138 149 176 273 274 286 461
                478 492 553 721 755 944 996 1039))
  #(107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
    721 755 755 944 944 996 1039 1039))

(deftest quantize-sv-sv.2
    (quantize #(100 141 155 168 171 200 250 280 300 350 400 450 470 486 500
                559 600 650 700 720.12345 750.05 800 900 950 1000 1100 10000)
              #(107 138 149 176 273 274 286 461
                478 492 553 721 755 944 996 1039)
              :start 5 :end 15)
  #(100 141 155 168 171 176 273 286 286 286 461 461 478 492 492 559
    600 650 700 720.1235 750.05 800 900 950 1000 1100 10000))

(deftest quantize-real-buffer.1
    (with-buffer (buf 16 :initial-contents '(107 138 149 176 273 274 286 461
                                             478 492 553 721 755 944 996 1039))
      (mapcar (lambda (x) (sample->fixnum (quantize x buf)))
              '(100 141 155 168 171 200 250 280
                300 350 400 450 470 486 500 559
                600 650 700 720.12345 750.05 800
                900 950 1000 1100 10000)))
  (107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 1039 1039))

(deftest quantize-real-buffer.2
    (with-buffer (buf 16 :initial-contents '(100 100 100 200 200 300 300 300
                                             300 400 400 500 600 600 600 600))
      (mapcar (lambda (x) (sample->fixnum (quantize x buf)))
              '(50 100 150 250 280 301 399 401 450 500 600 580 600 1000)))
  (100 100 200 300 300 300 400 400 500 500 600 600 600 600))

(deftest quantize-buffer-real.1
    (with-buffer (buf 7 :initial-contents '(11 23 19 123.456 31 49 999.999))
      (flet ((test (from)
               (mapcar #'sample->fixnum (buffer->list (quantize buf from)))))
        (quantize buf .75)
        (values (test .5) (test 3) (test 7))))
  (11 23 19 124 31 49 1000)
  (12 24 18 123 30 48 999)
  (14 21 21 126 28 49 1001))

(deftest quantize-buffer-real.2
    (with-buffer (buf 7 :initial-contents '(11 23 19 123.456 31 49 999.999))
      (flet ((test (from)
               (mapcar #'sample->fixnum
                       (buffer->list (quantize buf from :start 2 :end 5
                                       :filter-function (lambda (i x)
                                                          (declare (ignore i))
                                                          (truncate x .1)))))))
        (values (test .75) (test .5) (test 3) (test 7))))
  (11 23 187 1237 307 49 999)
  (11 23 1870 12370 3070 49 999)
  (11 23 18690 123690 30690 49 999)
  (11 23 186900 1236900 306880 49 999))

(deftest quantize-buffer-buffer.1
    (with-buffers ((buf 27
                    :initial-contents '(100 141 155 168 171 200 250 280 300 350
                                        400 450 470 486 500 559 600 650 700
                                        720.12345 750.05 800 900 950 1000 1100
                                        10000))
                   (from 16
                    :initial-contents '(107 138 149 176 273 274 286 461 478 492
                                        553 721 755 944 996 1039)))
      (mapcar #'sample->fixnum (buffer->list (quantize buf from))))
  (107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 1039 1039))

(deftest quantize-sv-buffer.1
    (with-buffer (from 16
                  :initial-contents '(107 138 149 176 273 274 286 461 478 492
                                      553 721 755 944 996 1039))
      (map 'list #'sample->fixnum
           (quantize #(100 141 155 168 171 200 250 280 300 350 400 450 470 486
                       500 559 600 650 700 720.12345 750.05 800 900 950 1000
                       1100 10000)
                     from)))
  (107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 1039 1039))

(deftest quantize-buffer-sv.1
    (with-buffer (buf 27
                  :initial-contents '(100 141 155 168 171 200 250 280 300 350
                                      400 450 470 486 500 559 600 650 700
                                      720.12345 750.05 800 900 950 1000 1100
                                      10000))
      (mapcar #'sample->fixnum
              (buffer->list (quantize buf #(107 138 149 176 273 274 286 461 478
                                            492 553 721 755 944 996 1039)))))
  (107 138 149 176 176 176 273 286 286 286 461 461 478 492 492 553 553 721 721
   721 755 755 944 944 996 1039 1039))

(deftest quantize-real-tuning.1
    (mapcar (lambda (x) (sample->fixnum (quantize x incudine::*tuning-et12*)))
            '(260 272 300 315 333 354 372 390 412 435 461 495))
  (261 277 293 311 329 349 369 391 415 440 466 493))

(deftest quantize-buffer-tuning.1
    (with-buffer (buf 12 :initial-contents '(260 272 300 315 333 354 372 390
                                             412 435 461 495))
      (mapcar #'sample->fixnum
              (buffer->list (quantize buf incudine::*tuning-et12*))))
  (261 277 293 311 329 349 369 391 415 440 466 493))

(deftest quantize-buffer-tuning.2
    (with-buffer (buf 12 :initial-contents '(260 315 387 460 260 315 387 460
                                             260 315 387 460))
      (mapcar #'sample->fixnum
              (buffer->list (quantize buf incudine::*tuning-et12*
                              :filter-function (lambda (i x)
                                                 (cond ((< i 4) (* x .5))
                                                       ((> i 7) (* x 2))
                                                       (t x)))))))
  (130 155 195 233 261 311 391 466 523 622 783 932))
