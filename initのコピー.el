;;; init-public-clean.el --- public Emacs config -*- lexical-binding: t; -*-
;;; Commentary:
;; Public-safe, cleaned-up Emacs configuration for macOS + Emacs 29.
;; Secrets are loaded via auth-source from ~/.authinfo.gpg.

;;; Code:

;; ============================================================
;; Custom settings
;; ============================================================
(setq custom-file (locate-user-emacs-file "custom.el"))
(when (file-exists-p custom-file)
  (load custom-file 'noerror))

;; ============================================================
;; load-path helpers
;; ============================================================
(defun add-to-load-path (&rest paths)
  "Add PATHS under `user-emacs-directory' and their subdirs to `load-path'."
  (dolist (path paths)
    (let ((default-directory
            (expand-file-name path user-emacs-directory)))
      (when (file-directory-p default-directory)
        (add-to-list 'load-path default-directory)
        (when (fboundp 'normal-top-level-add-subdirs-to-load-path)
          (normal-top-level-add-subdirs-to-load-path))))))

(add-to-load-path "elisp" "public_repos" "my-elisp")

;; ============================================================
;; package.el / use-package
;; ============================================================
(require 'package)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (require 'use-package nil t)
  (package-install 'use-package)
  (require 'use-package))

(setq use-package-always-ensure t
      use-package-always-defer t)

;; ============================================================
;; General settings
;; ============================================================

;; フォントをMonaco、サイズを16ピクセル相当に設定
(set-face-attribute 'default nil :family "Monaco" :height 140)

(when (fboundp 'mac-auto-ascii-mode)
  (mac-auto-ascii-mode 1))

(setq mouse-drag-copy-region t
      initial-scratch-message ""
      inhibit-startup-message t
      delete-by-moving-to-trash t)

(desktop-save-mode 1)

(let ((backup-dir (expand-file-name "~/.emacs.d/backups/")))
  (unless (file-directory-p backup-dir)
    (make-directory backup-dir t))
  (add-to-list 'backup-directory-alist (cons "." backup-dir))
  (setq auto-save-file-name-transforms
        `((".*" ,backup-dir t))))

(setq display-time-string-forms
      '((format "%s/%s/%s(%s) %s:%s"
                year month day dayname 24-hours minutes)
        load (if mail " Mail" ""))
      display-time-24hr-format t)

(when (boundp 'display-time-kawakami-form)
  (setq display-time-kawakami-form t))

(display-time)

(setq c-default-style
      '((c-mode . "java")
        (java-mode . "java")
        (awk-mode . "awk")
        (other . "gnu")))

(load-theme 'deeper-blue t)

;; ============================================================
;; Global key bindings
;; ============================================================
(global-set-key (kbd "C-t") #'other-window)

(when (boundp 'mac-command-modifier)
  (setq mac-command-modifier 'meta))

;; F5: 日時 (2026/03/22 22:25:00)
(global-set-key
 (kbd "<f5>")
 (lambda ()
   (interactive)
   (insert (format-time-string "%Y/%m/%d %H:%M:%S"))))

;; F6: 日付のみ (2026/03/22)
(global-set-key
 (kbd "<f6>")
 (lambda ()
   (interactive)
   (insert (format-time-string "%Y/%m/%d"))))

;; マウスの「Ctrl+スクロール」で文字サイズを変更する。
(global-set-key [C-mouse-wheel-up-event] 'text-scale-increase)
(global-set-key [C-mouse-wheel-down-event] 'text-scale-decrease)

;; ============================================================
;; GPG / auth-source
;; ============================================================
(require 'epa-file)
(require 'auth-source)

(epa-file-enable)

(setq epg-gpg-program (or (executable-find "gpg") epg-gpg-program)
      auth-sources '("~/.authinfo.gpg"))

(defun my/auth-source-secret (&rest plist)
  "Return :secret from `auth-source-search' as a string."
  (let* ((entry  (car (apply #'auth-source-search plist)))
         (secret (plist-get entry :secret)))
    (when secret
      (if (functionp secret) (funcall secret) secret))))

;; ============================================================
;; Packages
;; ============================================================
;; Emacsのフォントを"Hiragino Sans Mono"に固定する。
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x))
  :config
  (exec-path-from-shell-initialize))

(use-package company
  :hook (prog-mode . company-mode)
  :custom
  (company-idle-delay 0.2)
  (company-minimum-prefix-length 2))

;; (use-package yasnippet
;;   :hook (after-init . yas-global-mode))

;; (use-package yasnippet-snippets
;;   :after yasnippet)

;; (use-package paredit
;;   :hook ((emacs-lisp-mode
;;           lisp-interaction-mode
;;           lisp-mode
;;           ielm-mode) . enable-paredit-mode))

(autoload 'my-util-insert-tag "my-util" "Insert a tag." t)

;; ============================================================
;; Dired
;; ============================================================
(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :custom
  (dired-use-ls-dired nil)
  (ls-lisp-dirs-first t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'always)
  (dired-dwim-target t)
  :config
  (put 'dired-find-alternate-file 'disabled nil)
  (define-key dired-mode-map (kbd "RET") #'dired-find-alternate-file)
  (define-key dired-mode-map (kbd "a")   #'dired-find-file))

;; ============================================================
;; Org / mixed-pitch / export
;; ============================================================
(use-package org
  :ensure nil
  :hook
  (org-mode . (lambda ()
                (setq truncate-lines nil)))
  :config
  ;; org-table は等幅で表示
  (set-face-attribute 'org-table nil :inherit 'fixed-pitch)

  ;; 古い org-export-latex-* が残っている場合に備えて両対応
  (when (boundp 'org-export-latex-coding-system)
    (setq org-export-latex-coding-system 'shift_jis))
  (when (boundp 'org-export-latex-date-format)
    (setq org-export-latex-date-format "%Y-%m-%d"))

  ;; org-latex-* は ox-latex ロード後に設定する
  (with-eval-after-load 'ox-latex
    (setq org-latex-default-class "jsarticle")
    (add-to-list 'org-latex-classes
                 '("jsarticle"
                   "\\documentclass[a4j]{jsarticle}"
                   ("\\section{%s}" . "\\section*{%s}")
                   ("\\subsection{%s}" . "\\subsection*{%s}")
                   ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                   ("\\paragraph{%s}" . "\\paragraph*{%s}")
                   ("\\subparagraph{%s}" . "\\subparagraph*{%s}")))))

;; ============================================================
;; Utility commands
;; ============================================================
(defun replace-from-lt-to-entity-ref ()
  (interactive)
  (let ((num (char-after)))
    (delete-char 1)
    (insert (format "&lt;%s" num))))
(global-set-key (kbd "C-c C-c <") #'replace-from-lt-to-entity-ref)

(defun replace-from-gt-to-entity-ref ()
  (interactive)
  (let ((num (char-after)))
    (delete-char 1)
    (insert (format "&gt;%s" num))))
(global-set-key (kbd "C-c C-c >") #'replace-from-gt-to-entity-ref)

;; ============================================================
;; vterm / markdown
;; ============================================================
(use-package vterm
  :commands vterm
  :config
  (setq vterm-shell "/bin/zsh"
        vterm-max-scrollback 10000
        vterm-buffer-name-string "vterm %s"))

(use-package markdown-mode
  :mode  (("\\.md\\'" . markdown-mode)
          ("\\.markdown\\'" . markdown-mode)
          ("README\\.md\\'" . gfm-mode))
  :config
  (setq markdown-fontify-code-blocks-natively t
        markdown-hide-markup nil
        markdown-header-scaling t))

;; ============================================================
;; org-roam
;; ============================================================

(use-package org-roam
  :ensure t
  :after org
  :custom
  (org-roam-directory (file-truename "~/Documents/org-roam/"))

  ;; 検索候補での見え方を改善
  (org-roam-node-display-template
   (concat "${type:12} ${tags:20} ${title:*}"))

  ;; 補完を広げる
;  (org-roam-node-default-sort 'title)
  (org-roam-completion-everywhere t)

  ;; Capture templates
  (org-roam-capture-templates
   '(("p" "permanent" plain
      "%?"
      :if-new
      (file+head "notes/%<%Y%m%d%H%M%S>-${slug}.org"
                 "#+title: ${title}\n#+filetags: :note:\n\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n* 概要\n\n* 本文\n\n* 関連\n- \n\n* メモ\n- \n")
      :unnarrowed t)

     ("r" "reference" plain
      "%?"
      :if-new
      (file+head "references/%<%Y%m%d%H%M%S>-${slug}.org"
                 "#+title: ${title}\n#+filetags: :reference:\n\n:PROPERTIES:\n:AUTHOR: \n:SOURCE: \n:CREATED: %U\n:END:\n\n* 概要\n\n* 要点\n- \n- \n- \n\n* 引用\n#+begin_quote\n\n#+end_quote\n\n* 自分の考察\n- \n\n* 関連ノート\n- \n")
      :unnarrowed t)

     ("j" "project" plain
      "%?"
      :if-new
      (file+head "projects/%<%Y%m%d%H%M%S>-${slug}.org"
                 "#+title: ${title}\n#+filetags: :project:\n\n:PROPERTIES:\n:STATUS: active\n:CREATED: %U\n:END:\n\n* 目的\n\n* タスク\n** TODO \n** TODO \n\n* メモ\n- \n\n* 関連ノート\n- \n")
      :unnarrowed t)

     ("m" "moc" plain
      "%?"
      :if-new
      (file+head "mocs/%<%Y%m%d%H%M%S>-${slug}.org"
                 "#+title: ${title}\n#+filetags: :moc:\n\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n* 概要\n\n* トピック一覧\n- \n\n* カテゴリ別\n** 基礎\n- \n\n** 応用\n- \n\n** 参考\n- \n")
      :unnarrowed t)))

  ;; Dailies
  (org-roam-dailies-directory "daily/")
  (org-roam-dailies-capture-templates
   '(("d" "default" entry
      "* %<%H:%M> %?"
      :target
      (file+head "%<%Y-%m-%d>.org"
                 "#+title: %<%Y-%m-%d>\n#+filetags: :daily:\n\n* 今日の予定\n\n* ログ\n\n* 学び・気づき\n\n* 明日やること\n\n* あとでノート化\n"))))

  :bind (("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ("C-c n l" . org-roam-buffer-toggle)
         ("C-c n b" . org-roam-buffer-display-dedicated)
         ("C-c n g" . org-roam-graph)

         ;; dailies
         ("C-c n j" . org-roam-dailies-capture-today)
         ("C-c n t" . org-roam-dailies-goto-today)
         ("C-c n d" . org-roam-dailies-goto-date)
         ("C-c n y" . org-roam-dailies-goto-yesterday)
         ("C-c n m" . org-roam-dailies-goto-tomorrow)

         ;; node utilities
         ("C-c n e" . org-roam-extract-subtree)
         ("C-c n a" . org-roam-alias-add)
         ("C-c n T" . org-roam-tag-add)
         ("C-c n r" . org-roam-ref-add)

         ;; custom helpers
         ("C-c n n" . my/org-roam-create-note)
         ("C-c n p" . my/org-roam-create-project)
         ("C-c n M" . my/org-roam-create-moc)
         ("C-c n s" . my/org-roam-search-by-tag)
         ("C-c n x" . my/org-roam-convert-entry-to-node))

  :config
  (org-roam-db-autosync-mode)

  ;; type を保存先ディレクトリ名から推定して表示
  (cl-defmethod org-roam-node-type ((node org-roam-node))
    (condition-case nil
        (file-name-nondirectory
         (directory-file-name
          (file-name-directory
           (file-relative-name (org-roam-node-file node) org-roam-directory))))
      (error "")))

  ;; 作成日時の property を自動補完したい時に使える
  (defun my/org-roam--ensure-created-property ()
    "ファイルに CREATED property がなければ追加する。"
    (when (and buffer-file-name
               (string-prefix-p (expand-file-name org-roam-directory)
                                (expand-file-name buffer-file-name)))
      (save-excursion
        (goto-char (point-min))
        (unless (re-search-forward "^:CREATED:" nil t)
          (when (re-search-forward "^:PROPERTIES:$" nil t)
            (forward-line 1)
            (insert ":CREATED: " (format-time-string "[%Y-%m-%d %a %H:%M]") "\n"))))))

  (add-hook 'find-file-hook #'my/org-roam--ensure-created-property)

  ;; よく使う capture を直接呼ぶラッパー

  (defun my/org-roam-create-note (title)
  "permanent note を作成する。"
  (interactive "sTitle: ")
  (org-roam-capture-
   :node (org-roam-node-create :title title)
   :props '(:finalize find-file)
   :keys "p"))

(defun my/org-roam-create-project (title)
  "project note を作成する。"
  (interactive "sTitle: ")
  (org-roam-capture-
   :node (org-roam-node-create :title title)
   :props '(:finalize find-file)
   :keys "j"))

(defun my/org-roam-create-moc (title)
  "MOC note を作成する。"
  (interactive "sTitle: ")
  (org-roam-capture-
   :node (org-roam-node-create :title title)
   :props '(:finalize find-file)
   :keys "m"))

  ;; タグ検索
  (defun my/org-roam-search-by-tag (tag)
    "TAG を filetags に含む org-roam node を検索する。"
    (interactive "sTag: ")
    (org-roam-node-find
     nil nil
     (lambda (node)
       (member tag (org-roam-node-tags node)))))

  ;; subtree を抽出して node 化
  ;; daily の「あとでノート化」から permanent note を作る想定
  (defun my/org-roam-convert-entry-to-node ()
    "現在の subtree を org-roam node に変換する。"
    (interactive)
    (call-interactively #'org-roam-extract-subtree)
    (when (derived-mode-p 'org-mode)
      (save-excursion
        (goto-char (point-min))
        (unless (re-search-forward "^#\\+filetags:" nil t)
          (insert "#+filetags: :note:\n\n"))))))

(use-package org-roam-ui)

;; 全体像（運用モデル）
;; daily →（選別）→ permanent / reference / project → MOCで整理
;; daily = 入力バッファ
;; permanent = 知識
;; reference = 外部情報
;; project = 進行管理
;; MOC = ナビゲーション
;; 1. 日常の基本フロー（最重要）
;; 朝（1分）
;; C-c n t

;; → 今日のノートを開く

;; * 今日の予定
;; - 今日やることを書く
;; 作業中（常時）
;; C-c n j  （必要なら）

;; → とにかく daily に書く

;; * ログ
;; - 13:10 Emacs設定で詰まった
;; - 13:25 解決：原因は〜

;; * 学び・気づき
;; - org-roamはリンクが本質

;; 重要ルール

;; 整理しない
;; とにかく書く
;; 1行でもいい
;; 思いつき（即記録）

;; その場で

;; C-c n j

;; または daily に追記

;; * あとでノート化
;; - org-roamのMOCはかなり重要では？
;; 2. ノート昇格フロー（コア運用）
;; タイミング
;; 1日1回（夜 or 翌朝）
;; 5分でOK
;; 手順
;; ① daily を開く
;; C-c n t
;; ② 「あとでノート化」を見る
;; * あとでノート化
;; - org-roamのMOCはかなり重要では？
;; ③ 有用なものを昇格

;; カーソルを置いて

;; C-c n x

;; → subtree → node に変換

;; ④ permanent にする（必要なら）
;; C-c n n

;; 内容を整える：

;; * 概要
;; MOCは知識の入口になる

;; * 本文
;; - ノートを束ねる役割
;; - 検索より強いナビゲーション

;; * 関連
;; - [[id:...]]
;; 3. 文献ノート（インプット処理）
;; トリガー
;; 本を読む
;; 記事を読む
;; 技術調査
;; 手順
;; C-c n c → r
;; 書き方
;; * 概要
;; この本はorg-roamの運用方法について

;; * 要点
;; - ノートは小さく
;; - リンクが重要
;; - MOCを作る

;; * 自分の考察
;; - daily → permanent の流れが強い
;; ポイント
;; 「写す」ではなく「圧縮する」
;; 3〜5 bullet にまとめる
;; 4. プロジェクト管理
;; 新規プロジェクト
;; C-c n p
;; * 目的
;; org-roam環境を完成させる

;; * タスク
;; ** TODO capture改善
;; ** TODO UI整理

;; * メモ
;; - org-roam-uiは後回し
;; 運用
;; daily から project にリンク
;; [[id:project-id]]
;; project から daily を見返す必要はない
;; 5. MOC（知識のハブ）
;; 作成
;; C-c n M
;; 例
;; * 概要
;; org-roamの使い方まとめ

;; * トピック一覧
;; - [[id:permanent-note1]]
;; - [[id:permanent-note2]]

;; * カテゴリ別
;; ** 基礎
;; - ノート設計
;; - リンク戦略

;; ** 応用
;; - daily運用
;; - project連携
;; 使い方（重要）
;; 検索の代わりに使う
;; 「入口」として育てる
;; 6. 検索・探索フロー
;; ノード検索
;; C-c n f

;; 表示：

;; note        emacs           org-roamの使い方
;; project     work            新規機能開発
;; reference   book            ○○の要約
;; タグ検索
;; C-c n s

;; 例：

;; Tag: emacs
;; 挿入リンク
;; C-c n i
;; 7. 実践ルーチン（おすすめ）
;; 毎日（5分）
;; daily 書く
;; 昇格（1〜3件）
;; 週1（15分）
;; MOC 更新
;; project 見直し
;; 月1（30分）
;; 不要ノート削除
;; タグ整理
;; 8. この運用の核心

;; 重要なポイントだけ抽出します。

;; ① daily は「ゴミ箱であり宝庫」
;; 雑でOK
;; 後で価値が出る
;; ② permanent は「再利用可能な知識」
;; 1ノート1概念
;; 小さく
;; ③ MOC が「思考の入口」
;; 検索に頼らない
;; 構造で辿る
;; ④ リンクがすべて
;; [[id:...]]

;; これが増えるほど強くなる

;; 9. 最短で効果が出る使い方

;; 迷ったらこれだけやってください：

;; daily に全部書く
;; 毎日1つだけ permanent にする
;; 関連ノートに1リンク貼る

;; これだけでネットワークが成長します。



;; ============================================================
;; init-public-clean.el ends here
;; ============================================================

(provide 'init-public-clean)
;;; init-public-clean.el ends here
