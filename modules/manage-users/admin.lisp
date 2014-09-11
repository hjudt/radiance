#|
 This file is a part of TyNETv5/Radiance
 (c) 2014 TymoonNET/NexT http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:radiance-user)
(define-module #:manage-users
  (:use #:cl #:radiance))
(in-package #:manage-users)

(admin:define-panel manage users (:icon "fa-user")
  (r-clip:process
   (plump:parse (template "manage.ctml"))
   :users (user:list)))

(admin:define-panel edit users (:icon "fa-edit")
  (let* ((username (post/get "username"))
         (user (user:get username))
         (action (post/get "action"))
         (confirm (post/get "confirm")))
    (if user
        (cond
          ((and (not confirm) (string-equal action "delete"))
           (r-clip:process
            (plump:parse (template "confirm.ctml"))
            :username username))
          ((and confirm (not (string-equal confirm "yes")))
           (redirect "/users/manage"))
          ((string= action "Save")
           (loop for field in (user:fields user)
                 do (setf (user:field user field) (post-var field)))
           (user:save user)
           (redirect "/users/manage"))
          ((string= action "Discard")
           (user:discard user)
           (redirect "/users/manage"))
          ((string= action "Delete")
           (user:remove user)
           (redirect "/users/manage"))
          (T
           (when (string= action "Add")
             (setf (user:field user (post-var "key")) (post-var "val")))           
           (r-clip:process
            (plump:parse (template "edit.ctml"))
            :user user
            :fields (user:fields user))))
        (redirect "/users/manage"))))