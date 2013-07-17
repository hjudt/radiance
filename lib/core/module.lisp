#|
  This file is a part of TyNETv5/Radiance
  (c) 2013 TymoonNET/NexT http://tymoon.eu (shinmera@tymoon.eu)
  Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package :radiance)

(defvar *radiance-modules* (make-hash-table) "Map of all loaded modules.")

(define-condition module-already-initialized (error)
  ((module :initarg :module :reader module)))

(defclass column ()
  ((name :initform (error "Column name required.") :initarg :name :reader name :type string)
   (access-mode :initform "000" :initarg :access-mode :reader access-mode :type string)
   (description :initform NIL :initarg :description :reader description :type string))
  (:documentation "Abstract database column class for metadata purposes."))

(defclass collection (column)
  ((columns :initform (error "List of columns required.") :initarg :columns :reader columns :type simple-vector))
  (:documentation "Abstract database collection class for metadata purposes."))

(defmethod print-object ((col column) out)
  (print-unreadable-object (col out :type t)
    (format out "~a (~a)" (name col) (access-mode col))))

(defclass module ()
  ((name :initarg :name :reader name :type string :allocation :class)
   (author :initarg :author :reader author :type string :allocation :class)
   (version :initarg :version :reader version :type string :allocation :class)
   (license :initarg :license :reader license :type string :allocation :class)
   (url :initarg :url :reader url :type string :allocation :class)
   
   (collections :initarg :collections :reader collections :type list :allocation :class)
   (persistent :initform T :initarg :persistent :reader persistent :type boolean :allocation :class)

   (implements :initarg :implements :reader implementations :type list :allocation :class)
   (asdf-system :initarg :asdf-system :reader asdf-system :type symbol :allocation :class)
   (dependencies :initarg :dependencies :reader dependencies :type list :allocation :class)
   (compiled :initarg :compiled :reader compiled-p :type boolean :allocation :class))
  (:documentation "Radiance base module class."))

(defmethod print-object ((mod module) out)
  (print-unreadable-object (mod out :type t)
    (if (version mod) (format out "v~a" (version mod)))))

(defgeneric init (module)
  (:documentation "Called when Radiance is started up."))

(defgeneric shutdown (module)
  (:documentation "Called when Radiance is shut down."))

(defmacro defmodule (name superclasses docstring (&key fullname author version license url collections (persistent T) implements asdf-system dependencies compiled) &rest extra-slots)
  "Define a new Radiance module."
  (let ((superclasses (if (not superclasses) '(module) superclasses))
        (classdef (gensym "CLASSDEF"))
        (initializer (gensym "INITIALIZER")))
    `(flet ((,classdef () (log:info "Defining module ~a" ',name)
                       (defclass ,name ,superclasses
                         ((name :initarg :name :reader name :type string :allocation :class)
                          (author :initarg :author :reader author :type string :allocation :class)
                          (version :initarg :version :reader version :type string :allocation :class)
                          (license :initarg :license :reader license :type string :allocation :class)
                          (url :initarg :url :reader url :type string :allocation :class)
                          
                          (collections :initarg :collections :reader collections :type list :allocation :class)
                          (persistent :initform T :initarg :persistent :reader persistent :type boolean :allocation :class)
                          
                          (implements :initarg :implements :reader implementations :type list :allocation :class)
                          (asdf-system :initarg :asdf-system :reader asdf-system :type symbol :allocation :class)
                          (dependencies :initarg :dependencies :reader dependencies :type list :allocation :class)
                          (compiled :initarg :compiled :reader compiled-p :type boolean :allocation :class)
                          ,@extra-slots)
                         (:documentation ,docstring)))
            (,initializer () (log:info "Initializing module ~a" ',name)
                          (setf (gethash (make-keyword ',name) *radiance-modules*)
                                (make-instance ',name 
                                               :name ,fullname :author ,author :version ,version :license ,license :url ,url
                                               :collections ,collections :persistent ,persistent
                                               :implements ,implements :asdf-system ,asdf-system :dependencies ,dependencies
                                               :compiled ,compiled))))
       (restart-case (if (gethash ',name *radiance-modules*)
                         (error 'module-already-initialized :module ',name)
                         (progn (,classdef) (,initializer)))
       (override-both () 
         :report "Redefine the module and create a new instance of the module anyway."
         (,classdef) (,initializer))
       (override-module ()
         :report "Just redefine the module."
         (,classdef))
       (override-instance ()
         :report "Just create a new instance of the module."
         (,initializer))
       (do-nothing ()
         :report "Leave module and instance as they are.")))))

(defun make-column (name &key (access-mode "000") description)
  "Shorthand function to create a new column instance."
  (make-instance 'column :name name :access-mode access-mode :description description))

(defun make-collection (name &key (access-mode "000") description columns)
  "Create a new representation of a collection."
  (make-instance 'collection :name name :access-mode access-mode :description description
                 :columns (loop with array = (make-array (length columns) :element-type 'column :fill-pointer 0)
                             for column in columns
                             do (vector-push (if (listp column) 
                                                 (destructuring-bind (name &optional mode description) column
                                                   (make-column name :access-mode mode :description description))
                                                 (make-column column)) array)
                             finally (return array))))

(defgeneric get-module (module)
  (:documentation "Retrieves the requested module from the instance list."))

(defmethod get-module ((module symbol))
  "Retrieves the requested module from the instance list."
  (get-module (symbol-name module)))

(defmethod get-module ((module string))
  "Retrieves the requested module from the instance list."
  (gethash (make-keyword module) *radiance-modules*))