(in-package :incudine-tests)

(defmacro node-test-loop ((index min max) &body body)
  `(loop for ,index from ,min to ,max do ,@body))

(defun node-test-list ()
  (let ((acc nil))
    (dograph (n *root-node* (cdr (nreverse acc)))
      (push (list (node-id n) (node-name n) (group-p n)) acc))))

(defun node-test-list-id ()
  (mapcar 'first (node-test-list)))

(defun move-node-init-test ()
  (let ((groups '(400 300 200 100)))
    (mapc #'make-group groups)
    (dolist (g groups)
      (loop repeat 4 for i from (1+ g) do
              (play (lambda ()) :id i :tail g)))))

(defun check-empty-node-hash-items ()
  (assert
    (every #'null-node-p
           (incudine::int-hash-table-items incudine::*node-hash*)))
  t)

(deftest node.1
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (node-test-loop (i 1 *max-number-of-nodes*)
          (play (lambda ()) :id i))
        (push (live-nodes) res)
        (let ((node-list (node-test-list)))
          (push (length node-list) res)
          (push (equal (loop for i from *max-number-of-nodes* downto 1
                             collect (node-id (node i)))
                       (mapcar 'first node-list))
                res)
          (node-test-loop (i 1 *max-number-of-nodes*) (free i))
          (check-empty-node-hash-items)
          (push (node-test-list) res)
          (push (live-nodes) res)))
      res)
  (0 NIL T 1024 1024))

(deftest node.2
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (handler-case
            (node-test-loop (i 1 (* *max-number-of-nodes* 2))
              (play (lambda ()) :id i))
          (incudine-node-error (c) c (push t res)))
        (push (live-nodes) res)
        (node-test-loop (i 1 *max-number-of-nodes*) (free i))
        (push (live-nodes) res))
      res)
  (0 1024 T))

(deftest group.1
    (progn
      (free 0)
      (make-group 100)
      (make-group 200 :after 100)
      (values (incudine::node-funcons (node 200))
              (live-nodes)
              (progn (free 0) (live-nodes))))
  nil 2 0)

(deftest move-node.1
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (flet ((add-ids ()
                 (push (node-test-list-id) res))
               (after-p (n g)
                 (eq (incudine::node-next (incudine::node-last (node g)))
                     (node n)))
               (last-p (n g)
                 (= (node-id (incudine::node-last (node g))) n)))
          (move-node-init-test)  (add-ids)
          (move 300 :before 200) (add-ids)
          (move 200 :before 100) (add-ids)
          (move 103 :before 102) (add-ids)
          (move 104 :before 101) (add-ids)
          (move 100 :after  300) (add-ids)
          (move 200 :after  400) (add-ids)
          (move 402 :after  403) (add-ids)
          (move 104 :after  102) (add-ids)
          (move 400 :head   300) (add-ids)
          (push (after-p 301 400) res)
          (move 200 :head 400) (add-ids)
          (push (after-p 401 200) res)
          (move 200 :tail 100) (add-ids)
          (push (last-p 200 100) res)
          (move 300 :tail 200) (add-ids)
          (push (last-p 300 200) res)))
      (nreverse res))
  ((100 101 102 103 104 200 201 202 203 204 300 301 302 303 304 400 401 402 403 404)
   (100 101 102 103 104 300 301 302 303 304 200 201 202 203 204 400 401 402 403 404)
   (200 201 202 203 204 100 101 102 103 104 300 301 302 303 304 400 401 402 403 404)
   (200 201 202 203 204 100 101 103 102 104 300 301 302 303 304 400 401 402 403 404)
   (200 201 202 203 204 100 104 101 103 102 300 301 302 303 304 400 401 402 403 404)
   (200 201 202 203 204 300 301 302 303 304 100 104 101 103 102 400 401 402 403 404)
   (300 301 302 303 304 100 104 101 103 102 400 401 402 403 404 200 201 202 203 204)
   (300 301 302 303 304 100 104 101 103 102 400 401 403 402 404 200 201 202 203 204)
   (300 301 302 303 304 100 101 103 102 104 400 401 403 402 404 200 201 202 203 204)
   (300 400 401 403 402 404 301 302 303 304 100 101 103 102 104 200 201 202 203 204)
   T
   (300 400 200 201 202 203 204 401 403 402 404 301 302 303 304 100 101 103 102 104)
   T
   (300 400 401 403 402 404 301 302 303 304 100 101 103 102 104 200 201 202 203 204)
   T
   (100 101 103 102 104 200 201 202 203 204 300 400 401 403 402 404 301 302 303 304)
   T))

(deftest move-node.2
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (move-node-init-test)
        (let ((start-ids (node-test-list-id)))
          (flet ((moved-p ()
                   (push (not (equal (node-test-list-id) start-ids)) res)))
            (move 200 :after 100) (moved-p)
            (move 103 :after 102) (moved-p)
            (move 300 :before 400) (moved-p)
            (move 403 :before 404) (moved-p)
            (move 201 :head 200) (moved-p)
            (move 304 :tail 300) (moved-p)
            (move 200 :head 100)
            (setf start-ids (node-test-list-id))
            (move 200 :head 100) (moved-p)
            (move 200 :tail 100)
            (setf start-ids (node-test-list-id))
            (move 200 :tail 100) (moved-p))))
      (every #'null res))
  T)

(deftest move-node-loop-error.1
    (let ((loop-errors 0)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (macrolet ((loop-test (&body body)
                      `(handler-case (progn ,@body)
                         (incudine-node-error (c) c (incf loop-errors)))))
          (make-group 100)
          (make-group 200 :head 100)
          (make-group 300 :head 200)
          (loop-test (move 100 :head 200))
          (loop-test (move 100 :head 300))
          (loop-test (move 100 :tail 200))
          (loop-test (move 100 :tail 300))
          (loop-test (move 100 :before 300))
          (loop-test (move 100 :after 300))))
      (= loop-errors 6))
  T)

(deftest replace.1
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (flet ((node-test (max-nodes)
                 (node-test-loop (i 1 max-nodes)
                   (play (lambda ()) :id i :tail *root-node* :name "foo"))))
          (node-test (1- *max-number-of-nodes*))
          (let ((n (ash *max-number-of-nodes* -1)))
            (play (lambda ()) :replace n :name "bar")
            (push (equal (node-test-list)
                         (loop for i from 1 to (1- *max-number-of-nodes*)
                               collect (list i (if (= i n) "bar" "foo") nil)))
                  res)
            (free 0)
            (check-empty-node-hash-items)
            (push (node-test-list) res)
            ;; Replacing requires one freed node.
            (node-test *max-number-of-nodes*)
            (handler-case
                (play (lambda ()) :replace n :name "bar")
              (incudine-node-error (c)
                (push 'free-node-required res)))
            (free 0)
            (check-empty-node-hash-items)
            (push (live-nodes) res))))
      res)
  (0 FREE-NODE-REQUIRED NIL T))

(deftest replace.2
    (let ((res nil)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (flet ((update-result ()
                 (push (node-test-list) res)))
          (let ((g0 100))
            (make-group g0)
            (node-test-loop (i 1000 1005)
              (play (lambda ()) :id i :tail g0))
            (update-result)
            (play (lambda ()) :replace 100)
            (update-result)
            (free 100)
            (update-result)
            (let ((groups (list g0 200 300)))
              (mapc #'make-group groups)
              (loop for g in groups do
                      (node-test-loop (i 1000 1005)
                        (play (lambda ()) :id (+ g i) :head g)))
              (update-result)
              (play (lambda ()) :replace (second groups))
              (update-result)))))
      (nreverse res))
  (;; Before replacing.
   ((100 NIL T)
    (1000 NIL NIL) (1001 NIL NIL) (1002 NIL NIL)
    (1003 NIL NIL) (1004 NIL NIL) (1005 NIL NIL))
   ;; After replacing group 100 -> node.
   ((100 NIL NIL))
   NIL
   ;; Before replacing.
   ;; group 0
   ;;     group 300
   ;;         node 1305
   ;;         node 1304
   ;;         node 1303
   ;;         node 1302
   ;;         node 1301
   ;;         node 1300
   ;;     group 200
   ;;         node 1205
   ;;         node 1204
   ;;         node 1203
   ;;         node 1202
   ;;         node 1201
   ;;         node 1200
   ;;     group 100
   ;;         node 1105
   ;;         node 1104
   ;;         node 1103
   ;;         node 1102
   ;;         node 1101
   ;;         node 1100
   ;;
   ((300 NIL T)
    (1305 NIL NIL) (1304 NIL NIL) (1303 NIL NIL)
    (1302 NIL NIL) (1301 NIL NIL) (1300 NIL NIL)
    (200 NIL T)
    (1205 NIL NIL) (1204 NIL NIL) (1203 NIL NIL)
    (1202 NIL NIL) (1201 NIL NIL) (1200 NIL NIL)
    (100 NIL T)
    (1105 NIL NIL) (1104 NIL NIL) (1103 NIL NIL)
    (1102 NIL NIL) (1101 NIL NIL) (1100 NIL NIL))
   ;; After replacing group 200 -> node.
   ;; group 0
   ;;     group 300
   ;;         node 1305
   ;;         node 1304
   ;;         node 1303
   ;;         node 1302
   ;;         node 1301
   ;;         node 1300
   ;;     node 200
   ;;     group 100
   ;;         node 1105
   ;;         node 1104
   ;;         node 1103
   ;;         node 1102
   ;;         node 1101
   ;;         node 1100
   ;;
   ((300 NIL T)
    (1305 NIL NIL) (1304 NIL NIL) (1303 NIL NIL)
    (1302 NIL NIL) (1301 NIL NIL) (1300 NIL NIL)
    (200 NIL NIL)
    (100 NIL T)
    (1105 NIL NIL) (1104 NIL NIL) (1103 NIL NIL)
    (1102 NIL NIL) (1101 NIL NIL) (1100 NIL NIL))))

(deftest stop-group.1
    (let ((res nil)
          (g0 100)
          (*logger-stream* *null-output*))
      (bounce-to-buffer (*buffer-test-c1* :frames 1)
        (flet ((update-result ()
                 (push (node-test-list-id) res))
               (fill-group (group)
                 (node-test-loop (i 1000 1005)
                   (play (lambda ()) :id i :tail group))))
          (make-group 100)
          (fill-group g0)
          (update-result)
          (stop 100)
          (update-result)
          (fill-group g0)
          (update-result)
          (stop 0)
          (update-result)
          (fill-group g0)
          (move 1001 :head 0)
          (move 1002 :tail 0)
          (update-result)
          (stop 100)
          (update-result)
          (stop 0)
          (update-result)
          (fill-group g0)
          (move 1001 :head 0)
          (move 1002 :tail 0)
          (update-result)
          (stop 0)
          (update-result)))
      (nreverse res))
  (;; Fill group 100.
   (100 1000 1001 1002 1003 1004 1005)
   ;; STOP 100
   (100)
   ;; Refill.
   (100 1000 1001 1002 1003 1004 1005)
   ;; STOP 0
   (100)
   ;; Refill, then move 1001 and 1002.
   (1001 100 1000 1003 1004 1005 1002)
   ;; STOP 100
   (1001 100 1002)
   ;; STOP 0
   (100)
   ;; Refill, then move 1001 and 1002.
   (1001 100 1000 1003 1004 1005 1002)
   ;; STOP 0
   (100)))
