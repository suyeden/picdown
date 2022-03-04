;;; picdown.el --- script for downloading images -*- Emacs-Lisp -*-

;; Copyright (C) 2021 suyeden

;; Author: suyeden
;; Version: 1.0.0
;; Keywords: tools
;; Package-Requires: ((emacs "27.1") (master-lib "1.0.0") (eprintf.dll) (Google Chrome "98.0.4758.102") (curl "7.79.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; An image downloader script using curl and Headless-Chrome.

;;; Code:

(defvar pic-ext-original '("jpg" "jpeg" "JPG" "JPEG" "jpe" "jfif" "pjpeg" "pjp" "png" "gif" "svg" "svgz" "tif" "tiff" "webp" "pict" "bmp" "dib")
  "画像拡張子一覧")
(defvar pic-lib-path (expand-file-name (format "%s/../lib" load-file-name))
  "ライブラリは lib ディレクトリに格納する")

(defun main ()
  "画像ダウンロードスクリプト"
  (let ((url-list "picdown.txt")
        (dir-name nil)
        (dl-url-list nil))
    (load (expand-file-name "master-lib.el" pic-lib-path) nil t)
    (my-init)
    (if (file-exists-p url-list)
        (progn
          (while (string= "t" (format "%s" (judge-end url-list)))
            (setq dir-name (make-output-dir (read-url url-list)))
            (setq dl-url-list (make-dl-list (read-url url-list)))
            (setq dl-url-list (my-rm-same-atom dl-url-list))
            (my-princ (format "\n 残りURL : %s （このURLでのダウンロード予定ファイル数 : %s ）...\n" (my-count-line url-list) (length dl-url-list)))
            (output-log (read-url url-list) dl-url-list dir-name)
            (picdown-dl dl-url-list dir-name)
            (del-head-url url-list))
          (my-princ "\n ダウンロードが完了しました。\n\n"))
      (find-file url-list)
      (save-buffer)
      (kill-buffer url-list)
      (my-princ "\n 新しくテキストファイルを作成しました。URLをテキストファイルに入力してください。\n\n"))))

(defun make-output-dir (url)
  "画像のダウンロード先ディレクトリを作成し、作成したディレクトリの名前を返す"
  (let ((dir-name nil))
    (with-temp-buffer
      (insert (shell-command-to-string (format "curl.exe %s" url)))
      (goto-char (point-min))
      (re-search-forward "<title>\\(.+\\)</title>" nil t)
      (setq dir-name (buffer-substring (match-beginning 1) (match-end 1))))
    (setq dir-name (my-replace-invalid-filename dir-name))
    (setq dir-name (my-find-new-dirname dir-name))
    (make-directory dir-name)
    dir-name))

(defun make-dl-list (url)
  "指定URL先の画像URLを取得し、それらをまとめたリストを返す"
  (let ((dl-list-pre nil)
        (dl-list nil))
    ;; ダウンロード候補URLの切り取り
    (with-temp-buffer
      (insert (shell-command-to-string (format "\"%s\\Google\\Chrome\\Application\\chrome.exe\" --headless --enable-javascript --enable-logging --disable-gpu --dump-dom %s" "%ProgramFiles%" url)))
      (goto-char (point-min))
      (while (search-forward "<img" nil t)
        (search-forward "src=\"" nil t)
        (setq dl-list-pre (cons (buffer-substring (point) (progn (search-forward "\"" nil t) (forward-char -1) (point)))
                                dl-list-pre))))
    ;; 適切なURLに整形
    (while dl-list-pre
      (with-temp-buffer
        (insert (car dl-list-pre))
        (while (search-backward "?" nil t)
          (delete-region (point) (progn (end-of-line) (point))))
        (setq dl-list (cons (buffer-substring (point-min) (point-max))
                            dl-list)))
      (setq dl-list-pre (cdr dl-list-pre)))
    dl-list))

(defun picdown-dl (dl-list output-dir)
  "与えられた画像URLリストに基づいて画像をダウンロードする"
  (let ((initial-dl-list-length 0)
        (dl-progress-basic 5)
        (file-number 1)
        (dl-tmp-dir ".picdown_tmp"))
    (setq initial-dl-list-length (length dl-list))
    (my-princ "\n 進行状況（%） : 0")
    ;; 一時ディレクトリの作成
    (if (and (file-exists-p dl-tmp-dir) (file-directory-p dl-tmp-dir))
        (progn
          (delete-directory dl-tmp-dir t)
          (make-directory dl-tmp-dir))
      (make-directory dl-tmp-dir))
    (cd dl-tmp-dir)
    ;; ダウンロードループ
    (let ((dl-filename nil))
      (while dl-list
        (if (file-name-extension (car dl-list)) ; ダウンロードファイル名
            (setq dl-filename (format "tmp.%s" (file-name-extension (car dl-list))))
          (setq dl-filename "tmp"))
        (sit-for 3) ; マナー対策（5秒 - 画像移動後の2秒）
        (shell-command-to-string (format "curl.exe -L -o \"%s\" \"%s\"" dl-filename (car dl-list))) ; ダウンロード実行（ファイル名指定）
        (if (= 1 (length (my-exclude-invalid-file (directory-files ".")))) ; ダウンロードファイルのリネーム、移動
            ;; 1つのファイルだけが正常にダウンロードされていた場合
            (progn
              (setq dl-filename (car (my-exclude-invalid-file (directory-files "."))))
              (if (equal nil (file-name-extension dl-filename))
                  (rename-file dl-filename (format "../%s/%s (%s).jpg" output-dir output-dir file-number) t)
                (rename-file dl-filename (format "../%s/%s (%s).%s" output-dir output-dir file-number (file-name-extension dl-filename)) t)))
          ;; 2つ以上のファイルがダウンロードされていた、あるいは1つもダウンロードされていなかった場合
          (while (my-exclude-invalid-file (directory-files "."))
            (delete-file (car (my-exclude-invalid-file (directory-files ".")))))) ; ファイルが存在する場合は削除する
        (sit-for 2) ; マナー対策, 画像の移動にかかる時間を吸収するためこのタイミングでも実行する
        (while (<= (/ dl-progress-basic 100.0) (/ file-number (string-to-number (format "%s.0" initial-dl-list-length))))
          (if (= dl-progress-basic 25)
              (princ "25")
            (if (= dl-progress-basic 50)
                (princ "50")
              (if (= dl-progress-basic 75)
                  (princ "75")
                (if (= dl-progress-basic 100)
                    (princ "100")
                  (my-princ "■")))))
          (setq dl-progress-basic (+ dl-progress-basic 5)))
        (setq file-number (1+ file-number))
        (setq dl-list (cdr dl-list))))
    (princ "\n\n")
    (cd "../")
    (delete-directory dl-tmp-dir t)))

(defun read-url (filename)
  "'filename'ファイル中の先頭行の文字列を返す"
  (let ((head-url nil))
    (find-file filename)
    (goto-char (point-min))
    (setq head-url (buffer-substring (point) (progn (end-of-line) (point))))
    (kill-buffer filename)
    head-url))

(defun del-head-url (filename)
  "'filename'ファイル中の先頭行を削除する"
  (find-file filename)
  (goto-char (point-min))
  (delete-region (point) (progn (forward-line 1) (point)))
  (save-buffer)
  (kill-buffer filename)
  (my-del-extra-file filename))

(defun judge-end (filename)
  "'filename'ファイルの中身が空であれば nil、そうでなければ t を返す"
  (let ((state nil))
    (find-file filename)
    (if (= (point-min) (point-max))
        (setq state nil)
      (setq state t))
    (kill-buffer filename)
    state))

(defun output-log (url list output-dir)
  "ダウンロードログファイルを各ダウンロードディレクトリ内に作成する"
  (find-file (format "%s/picdown.log" output-dir))
  (insert (format "%s\n" (my-time)))
  (insert "\n")
  (insert "ダウンロード対象サイトのURL : \n")
  (insert (format "%s\n" url))
  (insert "\n")
  (insert (format "ダウンロードした画像の枚数 : %s\n" (length list)))
  (insert "\n")
  (insert "ダウンロードした画像URL : \n")
  (while list
    (insert (format "%s\n" (car list)))
    (setq list (cdr list)))
  (save-buffer)
  (kill-buffer (current-buffer))
  (my-del-extra-file (format "%s/picdown.log" output-dir)))

(defun my-princ (str)
  "標準出力関数"
  (my-print str pic-lib-path))

(defun my-read-str (str)
  "標準入力関数"
  (my-read-string str pic-lib-path))

(main)
;;; picdown.el ends here
