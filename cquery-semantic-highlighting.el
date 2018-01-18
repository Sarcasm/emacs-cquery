;;; -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Tobias Pisani

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and-or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Code:

(require 'cquery-common)

;; ---------------------------------------------------------------------
;;   Customization
;; ---------------------------------------------------------------------

(defface cquery-inactive-region-face
  '((t :foreground "#666666"))
  "The face used to mark inactive regions"
  :group 'cquery)

(defvar cquery-sem-face-function 'cquery-sem--default-face
  "A function used to determinate the face of a symbol.")

(defface cquery-sem-type-face
  '((t :weight bold :inherit font-lock-type-face))
  "The face used to mark types"
  :group 'cquery)

(defcustom cquery-sem-type-faces [cquery-sem-type-face]
  "."
  :type '(repeat face)
  :group 'cquery)

(defface cquery-sem-member-func-face
  '((t :slant italic :inherit font-lock-function-name-face))
  "The face used to mark member functions"
  :group 'cquery)

(defcustom cquery-sem-member-func-faces [cquery-sem-member-func-face]
  "."
  :type '(repeat face)
  :group 'cquery)

(defface cquery-sem-free-func-face
  '((t :inherit font-lock-function-name-face))
  "The face used to mark free functions"
  :group 'cquery)

(defcustom cquery-sem-free-func-faces [cquery-sem-free-func-face]
  "."
  :type '(repeat face)
  :group 'cquery)

(defface cquery-sem-member-var-face
  '((t :slant italic :inherit font-lock-variable-name-face))
  "The face used to mark member variables"
  :group 'cquery)

(defcustom cquery-sem-member-var-faces [cquery-sem-member-var-face]
  "."
  :type '(repeat face)
  :group 'cquery)

(defface cquery-sem-free-var-face
  '((t :inherit font-lock-variable-name-face))
  "The face used to mark local and namespace scope variables"
  :group 'cquery)

(defcustom cquery-sem-free-var-faces [cquery-sem-free-var-face]
  "."
  :type '(repeat face)
  :group 'cquery)

(defcustom cquery-rainbow-sem-type-colors
  '("#e1afc3" "#d533bb" "#9b677f" "#e350b6" "#a04360"
    "#dd82bc" "#de3864" "#ad3f87" "#dd7a90" "#e0438a")
  "Rainbow type colors."
  :type '(repeat string)
  :group 'cquery)

(defcustom cquery-rainbow-sem-func-colors
  '("#e5b124" "#927754" "#eb992c" "#e2bf8f" "#d67c17"
    "#88651e" "#e4b953" "#a36526" "#b28927" "#d69855")
  "Rainbow func colors."
  :type '(repeat string)
  :group 'cquery)

(defcustom cquery-rainbow-sem-var-colors
  '("#587d87" "#26cdca" "#397797" "#57c2cc" "#306b72"
    "#6cbcdf" "#368896" "#3ea0d2" "#48a5af" "#7ca6b7")
  "Rainbow var colors."
  :type '(repeat string)
  :group 'cquery)

(defface cquery-code-lens-face
  '((t :foreground "#777777"))
  "The face used for code lens overlays"
  :group 'cquery)

(defface cquery-code-lens-mouse-face
  '((t :box t))
  "The face used for code lens overlays"
  :group 'cquery)

(defcustom cquery-enable-sem-highlight
  t
  "Enable semantic highlighting."
  :type 'boolean
  :group 'cquery)

(defcustom cquery-sem-highlight-method
  'overlay
  "The method used to draw semantic highlighting.
overlays are more accurate than font-lock, but slower."
  :group 'lsp-mode
  :type '(radio
          (const :tag "overlays" overlay)
          (const :tag "font-lock" font-lock)))

(defcustom cquery-cache-dir
  ".vscode/cquery_cached_index/"
  "Directory in which cquery will store its index cache.
Relative to the project root directory."
  :type 'string
  :group 'cquery)

;; ---------------------------------------------------------------------
;;   Semantic highlighting
;; ---------------------------------------------------------------------

(defun cquery--clear-sem-highlights ()
  "."
  (pcase cquery-sem-highlight-method
    ('overlay
     (dolist (ov (overlays-in (point-min) (point-max)))
       (when (overlay-get ov 'cquery-sem-highlight)
         (delete-overlay ov))))
    ('font-lock
     (font-lock-ensure))))

(defun cquery--make-sem-highlight (region buffer face)
  "."
  (pcase cquery-sem-highlight-method
    ('overlay
     (let ((ov (make-overlay (car region) (cdr region) buffer)))
       (overlay-put ov 'face face)
       (overlay-put ov 'cquery-sem-highlight t)))
    ('font-lock
     (put-text-property (car region) (cdr region) 'font-lock-face face buffer))))

(defun cquery-sem--default-face (symbol)
  "."
  (let* ((type (gethash "type" symbol))
         (kind (gethash "kind" symbol))
         (stable-id (gethash "stableId" symbol))
         (is-type-member (gethash "isTypeMember" symbol))
         (fn0 (lambda (faces lo0 hi0)
                (let* ((n (length faces))
                       (lo (/ (* lo0 n) 1000))
                       (hi (/ (* hi0 n) 1000)))
                  (elt faces
                       (if (= lo hi) (1- hi) (+ lo (% stable-id (- hi lo))))))))
         (fn (lambda (faces) (elt faces (% stable-id (length faces))))))
    ;; cquery/src/indexer.h ClangSymbolKind
    ;; clang/Index/IndexSymbol.h clang::index::SymbolKind
    (pcase kind
      ;; var
      (4 (funcall fn0 cquery-sem-free-var-faces 600 700)) ; Macro
      (13 (funcall fn0 cquery-sem-free-var-faces 0 600)) ; Variable
      (25 (funcall fn0 cquery-sem-free-var-faces 700 1000)) ; Parameter
      (14 (funcall fn0 cquery-sem-member-var-faces 400 1000)) ; Field
      (15 (funcall fn0 cquery-sem-member-var-faces 200 400)) ; EnumConstant
      (21 (funcall fn0 cquery-sem-member-var-faces 0 200)) ; StaticProperty

      ;; func
      (12 (funcall fn0 cquery-sem-free-func-faces 0 800)) ; Function
      (18 (funcall fn0 cquery-sem-free-func-faces 800 1000)) ; StaticMethod
      (22 (funcall fn0 cquery-sem-member-func-faces 800 1000)) ; Constructor
      (23 (funcall fn0 cquery-sem-member-func-faces 1000 1000)) ; Destructor
      (24 (funcall fn0 cquery-sem-member-func-faces 1000 1000)) ; ConversionFunction
      (16 (funcall fn0 cquery-sem-member-func-faces 0 800)) ; InstanceMethod

      ;; type
      ((or 6 7) (funcall fn0 cquery-sem-type-faces 0 700)) ; Struct | Class
      (10 (funcall fn0 cquery-sem-type-faces 1000 1000)) ; Union
      (11 (funcall fn0 cquery-sem-type-faces 700 1000)) ; TypeAlias

      (_ (pcase type
           (0 (funcall fn cquery-sem-type-faces))
           (1 (if is-type-member
                  (funcall fn cquery-sem-member-func-faces)
                (funcall fn cquery-sem-free-func-faces)))
           (2 (if is-type-member
                  (funcall fn cquery-sem-member-var-faces)
                (funcall fn cquery-sem-free-var-faces))))))))

(defun cquery--publish-semantic-highlighting (_workspace params)
  "."
  (when cquery-enable-sem-highlight
    (let* ((file (cquery--uri-to-file (gethash "uri" params)))
           (buffer (find-buffer-visiting file))
           (symbols (gethash "symbols" params)))
      (when buffer
        (with-current-buffer buffer
          (save-excursion
            (with-silent-modifications
              (cquery--clear-sem-highlights)
              (dolist (symbol symbols)
                (-when-let (face (funcall cquery-sem-face-function symbol))
                  (dolist (range
                           (mapcar 'cquery--read-range (gethash "ranges" symbol)))
                    (cquery--make-sem-highlight range buffer face)))))))))))

(defmacro cquery-use-default-rainbow-sem-highlight ()
  (require 'dash)  ; for --map-indexed
  `(progn
     ;; type
     ,@(--map-indexed
        `(defface ,(intern (format "cquery-sem-type-face-%S" it-index))
           '((t :foreground ,it)) ".")
        cquery-rainbow-sem-type-colors)
     (setq cquery-sem-type-faces
           (apply #'vector (loop for i to 10 collect
                                 (intern (format "cquery-sem-type-face-%S" i)))))

     ;; func
     ,@(apply #'append (--map-indexed
                        `((defface ,(intern (format "cquery-sem-free-func-face-%S" it-index))
                            '((t :foreground ,it)) ".")
                          (defface ,(intern (format "cquery-sem-member-func-face-%S" it-index))
                            '((t :slant italic :foreground ,it)) "."))
                        cquery-rainbow-sem-func-colors))
     (setq cquery-sem-free-func-faces
           (apply #'vector (loop for i to 10 collect
                                 (intern (format "cquery-sem-free-func-face-%S" i)))))
     (setq cquery-sem-member-func-faces
           (apply #'vector (loop for i to 10 collect
                                 (intern (format "cquery-sem-member-func-face-%S" i)))))

     ;; var
     ,@(apply #'append (--map-indexed
                        `((defface ,(intern (format "cquery-sem-free-var-face-%S" it-index))
                            '((t :foreground ,it)) ".")
                          (defface ,(intern (format "cquery-sem-member-var-face-%S" it-index))
                            '((t :slant italic :foreground ,it)) "."))
                        cquery-rainbow-sem-var-colors))
     (setq cquery-sem-free-var-faces
           (apply #'vector (loop for i to 10 collect
                                 (intern (format "cquery-sem-free-var-face-%S" i)))))
     (setq cquery-sem-member-var-faces
           (apply #'vector (loop for i to 10 collect
                                 (intern (format "cquery-sem-member-var-face-%S" i)))))
     ))

;; Add handler
(push '("$cquery/publishSemanticHighlighting" . (lambda (w p) (cquery--publish-semantic-highlighting w p)))
      cquery--handlers)

;; ---------------------------------------------------------------------
;;   Inactive regions
;; ---------------------------------------------------------------------

(defun cquery--clear-inactive-regions ()
  "."
  (dolist (ov (overlays-in (point-min) (point-max)))
    (when (overlay-get ov 'cquery-inactive)
      (delete-overlay ov))))

(defun cquery--set-inactive-regions (_workspace params)
  "Put overlays on (preprocessed) inactive regions."
  (let* ((file (cquery--uri-to-file (gethash "uri" params)))
         (regions (mapcar 'cquery--read-range (gethash "inactiveRegions" params)))
         (buffer (find-buffer-visiting file)))
    (when buffer
      (with-current-buffer buffer
        (save-excursion
          (cquery--clear-inactive-regions)
          (overlay-recenter (point-max))
          (dolist (region regions)
            (let ((ov (make-overlay (car region) (cdr region) buffer)))
              (overlay-put ov 'face 'cquery-inactive-region-face)
              (overlay-put ov 'cquery-inactive t))))))))

;; Add handler
(push '("$cquery/setInactiveRegions" . (lambda (w p) (cquery--set-inactive-regions w p)))
      cquery--handlers)

(provide 'cquery-semantic-highlighting)