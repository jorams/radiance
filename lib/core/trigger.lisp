#|
  This file is a part of TyNETv5/Radiance
  (c) 2013 TymoonNET/NexT http://tymoon.eu (shinmera@tymoon.eu)
  Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package :radiance)

(defclass hook ()
  ((name :initform (error "Hook name required.") :initarg :name :accessor name :type symbol)
   (space :initform (error "Namespace required.") :initarg :space :accessor namespace :type symbol)
   (module :initform (error "Hook target module required.") :initarg :module :accessor module :type module)
   (function :initform (error "Hook module method required.") :initarg :function :accessor hook-function :type function)
   (fields :initform (make-hash-table) :initarg :fields :accessor fields :type hash-table)
   (description :initform NIL :initarg :description :accessor description :type string))
  (:documentation "Radiance hook class"))

(defmethod print-object ((hook hook) out)
  (print-unreadable-object (hook out :type T)
    (format out "~a/~a -> ~a:~a" (namespace hook) (name hook) (module hook) (hook-function hook))))

(defmethod hook-equal ((a hook) (b hook))
  "Checks if two hooks designate the same (match in space, module and name)."
  (and (equal (name a) (name b))
       (equal (name (module a)) (name (module b)))
       (eq (namespace a) (namespace b))))

(defmethod hook-equalp ((a hook) (b hook))
  "Checks if two hooks designate the same (match in space and name)."
  (and (equal (name a) (name b))
       (eq (namespace a) (namespace b))))

(defmethod hook-field ((hook hook) field)
  "Returns the value of a field defined on the hook or NIL."
  (gethash field (fields hook)))

(defun defhook (space name module function &key description fields replace-all)
  "Defines a new hook of name, for a certain function of a module. Fields should be an alist of additional fields on the hook."
  (let ((instance (make-instance 'hook :name name :space space :module module :function function :description description)))
    (log:info "Defining hook ~a" instance)
    (loop for (key . val) in fields
       do (setf (gethash key (fields instance)) val))
    (let ((namespace (gethash space *radiance-hooks*)))
      (unless namespace (add-namespace space))
      (when replace-all 
          (setf (gethash name namespace) (remove instance (gethash name namespace) :test #'hook-equalp)))
      (let ((pos (position instance (gethash name namespace) :test #'hook-equal)))
        (if pos 
            (setf (nth pos (gethash name namespace)) instance)
            (nappend (gethash name namespace) (list instance)))))
    instance))

(defun get-namespace-map ()
  "Retrieve the hash-map that contains all trigger namespaces."
  *radiance-hooks*)

(defun add-namespace (space &key ignore-defined)
  "Create a certain namespace."
  (restart-case 
      (let ((namespace (gethash space *radiance-hooks*)))
        (if (and (not ignore-defined) namespace) (error 'namespace-conflict :text (format nil "Namespace ~a already exists!" space)))
        (setf (gethash space *radiance-hooks*) (make-hash-table))
        space)
    (change-name (name) 
      :report "Create a different namespace."
      :interactive read
      (add-namespace name))
    (redefine () 
      :report "Override the definition."
      (add-namespace space :ignore-defined T))
    (skip () 
      :report "Don't define anything.")))

(defun get-namespace (space &key ignore-undefined)
  "Retrieve a certain namespace."
  (let ((namespace (gethash space *radiance-hooks*)))
    (if (and (not ignore-undefined) (not namespace)) (error "Unknown trigger namespace ~a" space))
    namespace))

(defun get-triggers (space)
  "Retrieve all triggers of a namespace."
  (alexandria:hash-table-keys (get-namespace space)))

(defun get-hooks (space trigger)
  "Retrieve all hooks for a trigger."
  (gethash trigger (get-namespace space)))

(defun trigger (space trigger &rest args)
  "Trigger a certain hook and collect all return values."
  (loop for hook in (gethash trigger (get-namespace space))
     collect (let* ((module (module hook)))
               (unless (persistent module)
                 (setf module (make-instance (class-of module))))
               (apply (hook-function hook) module args))))

(add-namespace :server)
(add-namespace :api)
(add-namespace :page)
