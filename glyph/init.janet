#!/bin/env janet
(import spork :prefix "")
(import ./glob :export true)
(import ./util :export true)
(import ./git :export true)
(import ./config :prefix "" :export true)
(import ./modules :prefix "" :export true)
(import ./scripts :export true)
(import ./jobs :export true)

(defn sync
  "synchronize glyph archive"
  []
  (os/execute ["git" "-C" (dyn :arch-dir) "pull" "--recurse-submodules=no"] :p)
  (os/execute ["git" "-C" (dyn :arch-dir) "submodule" "update" "--merge" "--recursive"] :p)
  (scripts/sync/exec)
  (jobs/exec)
  (os/execute ["git" "-C" (dyn :arch-dir) "push"] :p))

(defn fsck []
  (def arch-dir (dyn :arch-dir))
  (print "Starting normal recursive git fsck...")
  (git/fsck arch-dir)
  (print)
  (each name (modules/ls)
    (def module (modules/get name))
    (def info-path (path/join arch-dir (module :path) ".main.info.json"))
    (if (os/stat info-path)
        (do (def info (json/decode (slurp info-path)))
            (if (index-of "fsck" (info "supported"))
                (do (print "Starting additional fsck for  " name)
                    (modules/execute name ["fsck"])))))))
