#|
  This file is a part of TyNETv5/Radiance
  (c) 2013 TymoonNET/NexT http://tymoon.eu (shinmera@tymoon.eu)
  Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package :radiance)

(defmodule core ()
  "Radiance Core Module, Mostly used for API."
  (:fullname "Radiance Core" 
   :author "Nicolas Hafner" 
   :version "5.0.1"
   :license "Artistic" 
   :url "http://tymoon.eu"

   :implements '()
   :dependencies ()
   :compiled T)
  ())

(defmacro defapi (name (&rest args) (&key (module (get-module T)) (modulevar (gensym "MODULE")) access-branch) &body body)
  "Defines a new API function for the given module. The arguments specify
REST values that are expected (or not according to definition) on the
API call. Any variable can have a default value specified. If 
access-branch is given, an authorization check on the current session
at page load will be performed. The return value of the body should be
a plist or an URI. This will automatically be transformed into the
requested output type or a page redirect in the case of an URI."
  (assert (not (eql module NIL)) () "Module cannot be NIL! (Are you in-module context?)")
  (let ((fullname (intern (format nil "API-~a" name)))
        (name (make-keyword name))
        (funcbody `(progn ,@body))
        (modgens (gensym "MODULE")))
    `(let ((,modgens (get-module ,(module-symbol module))))
       (defmethod ,fullname ((,modulevar (eql ,modgens)))
         (declare (ignorable ,modulevar))
         (let (,@(loop for arg in args 
                    for argname = (if (listp arg) (car arg) arg) 
                    for lit = (string-downcase (format NIL "~a" argname))
                    collect `(,argname (or (post-var ,lit) (get-var ,lit) ,(if (listp arg) (second arg))))))
           ,@(loop for arg in args
                if (not (listp arg))
                collect `(if (not ,arg) (error 'api-args-error :module ,modulevar :apicall ',name :text (format NIL "Argument ~a required." ',arg)))) 
           ,(if access-branch
                `(if (authorized-p ,access-branch)
                     ,funcbody
                     (error-page 403))
                funcbody)))
       (defhook :api ',name ,modgens #',fullname
                :description ,(format nil "API call for ~a" module)))))

(defpage api #u"/api/" (:modulevar module)
  (let ((pathparts (split-sequence:split-sequence #\/ (path *radiance-request*)))
        (format (make-keyword (or (get-var "format") (post-var "format") "json"))))
    (api-format 
     format
     (handler-case 
         (case (length pathparts)
           ((1 2) (api-return 200 (format NIL "Radiance API v~a" (version module))
                              (plist->hash-table :VERSION (version module) :TIME (get-unix-time))))
           (otherwise
            (let* ((module (cadr pathparts))
                   (trigger (make-keyword (concatenate-strings (cddr pathparts) "/")))
                   (hooks (get-hooks :api trigger)))
              (or (call-api module hooks)
                  (api-return 204 "No return data")))))
       (api-args-error (c)
         (api-return 400 "Invalid arguments"
                     (plist->hash-table :errortype (class-name (class-of c)) 
                                        :code (slot-value c 'code)
                                        :text (slot-value c 'text))))
       (api-error (c)
         (api-return 500 "Api error"
                     (plist->hash-table :errortype (class-name (class-of c))
                                        :code (slot-value c 'code)
                                        :text (slot-value c 'text))))))))

(defun api-return (code text &optional data)
  "Generates an API response in the proper format:
  (:CODE code :TEXT text :DATA data)"
  (plist->hash-table :CODE code :TEXT text :DATA data))

(defun call-api (module hooks)
  (loop with return = ()
     with accepted = NIL
     for hook in hooks
     if (string-equal (class-name (class-of (module hook))) module)
     do (setf accepted T)
       (nappend return (funcall (hook-function hook) (module hook)))
     finally (return (if accepted
                         return
                         (api-return 404 "Call not found")))))

(defun api-format (format data)
  "Turn a plist into the requested format."
  (let ((format (gethash format *radiance-api-formats*)))
    (if format
        (progn
          (setf (hunchentoot:content-type* *radiance-reply*) (second format))
          (funcall (third format) data))
        (plist->format :none NIL))))

(defmacro define-api-format (name content-type datavar &body body)
  "Define a new API output format function."
  (let ((name (make-keyword name)))
    `(setf (gethash ,name *radiance-api-formats*)
           (list ,name ,content-type
                 (lambda (,datavar) ,@body)))))
             
(define-api-format json "application/json" data
  (cl-json:encode-json-to-string data))

(define-api-format none "text/plain; charset=utf-8" data
  (declare (ignore data))
  "Unknown format.")

(defapi formats () ()
  (api-return 200 "Available output formats" (alexandria:hash-table-keys *radiance-api-formats*)))

(defapi version () (:modulevar module)
  (api-return 200 "Radiance Version" (version module)))

(defapi host () ()
  (api-return 200 "Host information" 
              (plist->hash-table
               :machine-instance (machine-instance)
               :machine-type (machine-type)
               :machine-version (machine-version)
               :software-type (software-type)
               :software-version (software-version)
               :lisp-implementation-type (lisp-implementation-type)
               :lisp-implementation-version (lisp-implementation-version))))

(defapi modules () ()
  (api-return 200 "Module listing"
              (alexandria:hash-table-keys *radiance-modules*)))

(defapi server () (:modulevar module)
  (api-return 200 "Server information"
              (plist->hash-table
               :string (format nil "TyNET-~a-SBCL~a-α" (version module) (lisp-implementation-version))
               :ports (config :ports)
               :uptime (- (get-unix-time) *radiance-startup-time*)
               :time (get-unix-time)
               :request-count *radiance-request-count*
               :request-total *radiance-request-total*)))

(defapi noop () ())

(defapi echo () ()
  (api-return 200 "Echo data" (list :post (post-vars) :get (get-vars))))

(defapi user () ()
  (api-return 200 "User data"
              (plist->hash-table
               :authenticated (authenticated-p)
               :session-active (if *radiance-session* T NIL))

(defapi error () ()
  (error 'api-error :text "Api error as requested" :code -42))

(defapi coffee () ()
  (api-return 418 "I'm a teapot"
              (plist->hash-table
               :temperature (+ 75 (random 10))
               :active T
               :capacity 1
               :content (/ (+ (random 20) 80) 100)
               :flavour (alexandria:random-elt '("rose hip" "peppermint" "english breakfast")))))