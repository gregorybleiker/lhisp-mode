;;; lhisp.el --- change font color of parens
;;; Commentary:
;;; A minor mode to toggle parentheses coloring in Lisp modes
;;; Code:

;; Variable to store current face state
(defvar my-paren-currently-active nil
  "State of lhisp mode highlighting. t means hidden, nil means normal")

;; Variable to store original parenthesis keywords before modification
(defvar my-paren-original-keywords nil
  "Storage for original font-lock keywords that affect parentheses.")

;; Define a face that matches background (for hiding parens)
(defface my-paren-hidden-face
  '((t (:foreground unspecified)))
  "Face for hiding parentheses by matching background color.")

;; Function to get current background color
(defun my-paren-get-background-color ()
  "Get the current background color of the default face."
  (or (face-background 'default nil t)
      (face-background 'default)
      "#000000")) ; fallback to black if no background found

;; Function to update hidden face with current background color
(defun my-paren-update-hidden-face ()
  "Update the hidden face to match current background color."
  (let ((bg-color (my-paren-get-background-color)))
    (set-face-attribute 'my-paren-hidden-face nil :foreground bg-color)))

;; Function to save current parenthesis highlighting
(defun my-paren-save-original-highlighting ()
  "Save the current font-lock keywords that affect parentheses."
  (setq my-paren-original-keywords
        (cl-remove-if-not
         (lambda (keyword)
           (and (listp keyword)
                (stringp (car keyword))
                (string-match-p "(\\|)\\|\\[\\|\\]\\|{\\|}" (car keyword))))
         font-lock-keywords)))

;; Function to restore original parenthesis highlighting
(defun my-paren-restore-original-highlighting ()
  "Restore the original parenthesis highlighting."
  (my-paren-highlighting-remove)
  (when my-paren-original-keywords
    (font-lock-add-keywords nil my-paren-original-keywords 'append))
  ;; Force complete font-lock refresh
  (font-lock-mode -1)
  (font-lock-mode 1))

;; Variable to store face remapping cookies
(defvar my-paren-face-remaps nil
  "List of face remap cookies to clean up later.")

;; Function to add hidden parenthesis highlighting
(defun my-paren-highlighting-hidden ()
  "Hide parentheses by coloring them like the background."
  (my-paren-update-hidden-face) ; Update face with current background color

  ;; Remove any existing face remaps first
  (dolist (cookie my-paren-face-remaps)
    (face-remap-remove-relative cookie))
  (setq my-paren-face-remaps nil)

  ;; Override parinfer faces specifically, but preserve show-paren highlighting
  (when (bound-and-true-p parinfer-rust-mode)
    (let ((bg-color (my-paren-get-background-color)))
      ;; Override parinfer's parenthesis faces but NOT show-paren faces
      (push (face-remap-add-relative 'parinfer-rust-paren-face
                                     :foreground bg-color)
            my-paren-face-remaps)
      (push (face-remap-add-relative 'parinfer-rust-dim-parens
                                     :foreground bg-color)
            my-paren-face-remaps)))

  ;; Use font-lock keywords but with a more specific regex that avoids cursor position
  (font-lock-add-keywords
   nil
   '(("\\((\\|)\\|\\[\\|\\]\\|{\\|}\\)" 1 'my-paren-hidden-face prepend))
   'prepend)

  ;; Force complete font-lock refresh
  (font-lock-mode -1)
  (font-lock-mode 1)
  (setq my-paren-currently-active t))

;; Function to remove the highlighting
(defun my-paren-highlighting-remove ()
  "Remove custom parenthesis highlighting."
  (font-lock-remove-keywords
   nil
   '(("\\((\\|)\\|\\[\\|\\]\\|{\\|}\\)" 1 'my-paren-hidden-face prepend)))

  ;; Remove all face remappings
  (dolist (cookie my-paren-face-remaps)
    (face-remap-remove-relative cookie))
  (setq my-paren-face-remaps nil)

  ;; Force complete font-lock refresh to ensure all highlighting is cleared
  (font-lock-mode -1)
  (font-lock-mode 1))

;; Toggle between faces
(defun my-paren-toggle-face ()
  "Toggle between normal and hidden parentheses."
  (interactive)
  (if my-paren-currently-active
      ;; Currently hidden -> restore normal
      (progn
        (my-paren-restore-original-highlighting)
        (setq my-paren-currently-active nil)
        (message "Parentheses restored to normal"))
    ;; Currently normal -> make hidden
    (progn
      (my-paren-highlighting-hidden)
      (message "Parentheses hidden"))))

;; Define the minor mode
(define-minor-mode lhisp-mode
  "Toggle lhisp mode.
Interactively with no argument, this command toggles the mode.
A positive prefix argument enables the mode, any other prefix
argument disables it.  From Lisp, argument omitted or nil enables
the mode, `toggle' toggles the state.

When lhisp mode is enabled, you can use C-c , to toggle between:
1. Normal parentheses (preserves existing highlighting)
2. Hidden parentheses (same color as background)"
  ;; The initial value.
  :init-value nil
  ;; The indicator for the mode line.
  :lighter " lhisp"
  ;; The minor mode bindings.
  :keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c ,") 'my-paren-toggle-face)
    map)
  ;; Mode activation/deactivation
  (if lhisp-mode
      (progn
        (my-paren-save-original-highlighting)
        ;; Activate parinfer-rust-mode if available
        (when (fboundp 'parinfer-rust-mode)
          (parinfer-rust-mode 1))
        (message "lhisp mode enabled - use C-c , to toggle paren visibility"))
    (progn
      (my-paren-restore-original-highlighting)
      (setq my-paren-currently-active nil)
      ;; Deactivate parinfer-rust-mode if it was activated
      (when (and (fboundp 'parinfer-rust-mode)
                 (bound-and-true-p parinfer-rust-mode))
        (parinfer-rust-mode -1))
      (message "lhisp mode disabled"))))

(provide 'lhisp)
;;; lhisp.el ends here
