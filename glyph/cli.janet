(import ./init :prefix "" :export true)
(import ./options :export true)
(use spork)

# TODO for cosmo integration
# support a collection that has different git dir and working dir
# add some functionalty to generate a prompt efficiently (maybe integrate cosmo into core?)
# add sync status management
# add pre-sync and post-sync hooks?
# write hosts db script? (just implement as script?)
# add setup and node management logic to core config and node management
# add message management (just implement as script?)
# add sigchain
# add universal vars
# (defn sync/status []
#   (if (cosmo/sync/enabled?)
#     (os/exit 0)
#     (os/exit 1)))
# TODO add sync management
# (defn sync/status/print []
#   (if (cosmo/sync/enabled?)
#     (print "Sync enabled!")
#     (print "Sync disabled!")))

(def cli/store/help
  `Store allows storing objects and strings in the cosmo git repo, available subcommands are:
    get $KEY - Prints the value for key without extra newline
    set $KEY $VALUE - Set a key to the given value
    ls $OPTIONAL_PATTERN - If glob-pattern was given, list all keys matching it, else list all
    rm $KEY - Delete the key`)

(defn print_val [val]
  (case (type val)
    :string (print val)
    :buffer (print val)
    (print (string/format "%j" val))))

(defn cli/store/handler [raw-args]
  (def args (options/parse
    :description "Store allows storing objects and strings in the cosmo git repo"
    :options {"global" {:kind :flag
                        :short "g"
                        :help "Work on global store, this is the default"}
             "local" {:kind :flag
                      :short "l"
                      :help "Work on local store"}
             "groups" {:kind :accumulate
                       :short "t"
                       :help "The groups the secret should be encrypted for (implies --global)"}
             :default {:kind :accumulate
                       :help store/help}}
     :args ["glyph" ;raw-args]))
  (unless args (os/exit 1))
  (if (not (args :default))
    (do (print store/help)
        (os/exit 0)))
  # TODO pass --groups to store once encryption support is there
  (if (args "groups") (put args "global" true))
  (if (args "global") (put args "local" nil))
  (case ((args :default) 0)
    "get" (if (args "local")
            (do
              (if (< (length (args :default)) 2) (error "Key to get not specified"))
              (let [val (cosmo/cache/get ((args :default) 1))]
                (print_val val)))
            (do
              (if (< (length (args :default)) 2) (error "Key to get not specified"))
              (let [val (cosmo/store/get ((args :default) 1))]
                (print_val val))))
    "set" (do (if (< (length (args :default)) 3) (error "Key or value to set not specified"))
              (def val (parse ((args :default) 2)))
              (if (args "local")
                (cosmo/cache/set ((args :default) 1) val)
                (cosmo/store/set ((args :default) 1) val)))
    "ls"  (if (args "local") # TODO think of better way for passing list to user (human readable key=value but if --json is given print list as json?)
            (let [patt (if (> (length (args :default)) 1) (string/join (slice (args :default) 1 -1) "/") nil)
                list (cosmo/cache/ls-contents patt)]
              (print (string/format "%P" list)))
            (let [patt (if (> (length (args :default)) 1) (string/join (slice (args :default) 1 -1) "/") nil)
                list (cosmo/store/ls-contents patt)]
              (print (string/format "%P" list))))
    "rm"  (if (args "local")
            (do (if (< (length (args :default)) 2) (error "Key to delete not specified"))
              (cosmo/cache/rm ((args :default) 1)))
            (do (if (< (length (args :default)) 2) (error "Key to delete not specified"))
              (cosmo/store/rm ((args :default) 1))))
    (do (eprint "Unknown subcommand")
        (os/exit 1))))

(def universal-vars/help
  `Universal vars are environment variables that are sourced at the beginning of a shell session.
  This allows to have local env-vars that are either machine specific or shared among all.
  To create an environment variable use the store, all variables are stored under the vars/* prefix
  Available Subcommands:
    export $optional_pattern - return the  environment variables matching pattern, all if none is given in a format that can be evaled by posix shells`)

(defn cli/collections/add [args]
  (def res
    (options/parse
      :description "Add a new collection to the glyph archive"
      :options {"name" {:kind :option
                        :required true
                        :short "n"
                        :help "the name of the new collection"}
                "remote" {:kind :option
                          :required true
                          :short "r"
                          :help "git remote url of the new collection"}
                "description" {:kind :option
                               :required true
                               :short "d"
                               :help "the description of the new collection"}}
      :args ["glyph" ;args]))
  (unless res (os/exit 1))
  (collections/add (res "name") (res "description") (res "remote"))
  (print "Collection was recorded in config, you can now initialize it using glyph collections init `" (res "name") "`"))

(defn cli/collections/ls [&opt args]
  (print
    (string/join
      (map (fn [name]
             (def collection (collections/get name))
             (string name " - " (collection :description)
                     (if (collection :cached)
                         (string " @ " (collection :path)))))
           (collections/ls (if args (first args) nil)))
    "\n")))

(defn cli/collections/nuke [name]
  (if (not name) (do (print "Specify collection to remove!") (os/exit 1)))
  (def collection (collections/get name))
  (if (not collection) (do (print "Collection " name " not found, aborting...") (os/exit 1)))
  (collections/deinit name)
  (collections/nuke name)
  (collections/gc)
  (print "collection " name " was deleted"))

(defn cli/collections/help []
  (print `Available Subcommands:
           add - add a new collection
           ls - list collections
           rm - remove a collection
           init - initialize an existing collection
           deinit - deinitialize a cached collection
           help - show this help`))

(defn cli/collections/init [name]
  (if (or (not name) (= name "")) (do (print "Specify collection to initialize by name, aborting...") (os/exit 1)))
  (def collection (collections/get name))
  (if (not collection) (error (string "Collection " name " not found, aborting...")))
  (if (collection :cached) (error (string "Collection" name " already initialized")))
  (collections/init name))

(defn cli/collections/deinit [name]
  (def arch-dir (util/arch-dir))
  (if (not name) (do (print "Specify collection to deinitialize by name, aborting...") (os/exit 1)))
  (def collection (collection/get name))
  (if (or (not collection) (not (collection :cached))) (do (print "Collection " name " not found, aborting...") (os/exit 1)))
  (collections/deinit name))


(def store/help
  `Store allows storing objects and strings in the cosmo git repo, available subcommands are:
    get $KEY - Prints the value for key without extra newline
    set $KEY $VALUE - Set a key to the given value
    ls $OPTIONAL_PATTERN - If glob-pattern was given, list all keys matching it, else list all
    rm $KEY - Delete the key`)

(def store/argparse
  ["Store allows storing objects and strings in the cosmo git repo"
   "global" {:kind :flag
             :short "g"
             :help "Work on global store, this is the default"}
   "local" {:kind :flag
            :short "l"
            :help "Work on local store"}
   "groups" {:kind :accumulate
             :short "t"
             :help "The groups the secret should be encrypted for (implies --global)"}
   :default {:kind :accumulate
             :help store/help}])

(defn print_val [val]
  (if (or (= (type val) :string) (= (type val) :buffer))
      (print val)
      (print (string/format "%j" val))))

(defn store/handler [args]
  (setdyn :args @[((dyn :args) 0) ;(slice (dyn :args) 2 -1)])
  (def args (argparse/argparse ;store/argparse))
  (unless args (os/exit 1))
  (if (not (args :default))
    (do (print store/help)
        (os/exit 0)))
  # TODO pass --groups to store once encryption support is there
  (if (args "groups") (put args "global" true))
  (if (args "global") (put args "local" nil))
  (case ((args :default) 0)
    "get" (if (args "local")
            (do
              (if (< (length (args :default)) 2) (error "Key to get not specified"))
              (let [val (cosmo/cache/get ((args :default) 1))]
                (print_val val)))
            (do
              (if (< (length (args :default)) 2) (error "Key to get not specified"))
              (let [val (cosmo/store/get ((args :default) 1))]
                (print_val val))))
    "set" (if (args "local")
            (do (if (< (length (args :default)) 3) (error "Key or value to set not specified"))
              (cosmo/cache/set ((args :default) 1) ((args :default) 2)))
            (do (if (< (length (args :default)) 3) (error "Key or value to set not specified"))
              (cosmo/store/set ((args :default) 1) ((args :default) 2))))
    "ls"  (if (args "local") # TODO think of better way for passing list to user (human readable key=value but if --json is given print list as json?)
            (let [patt (if (> (length (args :default)) 1) (string/join (slice (args :default) 1 -1) "/") nil)
                list (cosmo/cache/ls-contents patt)]
              (print (string/format "%P" list)))
            (let [patt (if (> (length (args :default)) 1) (string/join (slice (args :default) 1 -1) "/") nil)
                list (cosmo/store/ls-contents patt)]
              (print (string/format "%P" list))))
    "rm"  (if (args "local")
            (do (if (< (length (args :default)) 2) (error "Key to delete not specified"))
              (cosmo/cache/rm ((args :default) 1)))
            (do (if (< (length (args :default)) 2) (error "Key to delete not specified"))
              (cosmo/store/rm ((args :default) 1))))
    (do (eprint "Unknown subcommand")
        (os/exit 1))))

(defn cli/setup/collections [args]
  (error "Not implemented yet")) # TODO implement collections setup using jeff + interactive wizard

(defn cli/setup/help [args]
  (print `To setup your own glyph archive you just need to do following things:
           1. create a directory at ${GLYPH_DIR:-~/.glyph}
           2. use glyph git init to initialize the git repo
           3. add a git remote
           4. add your glyph collections with glyph collections add
           5. profit
         If you already have a glyph repo setup you can simply clone it via git clone.
         After cloning use glyph setup collections to set up your collections`))

(defn cli/setup [args]
  (case (first args)
    "collections" (cli/setup/collections (slice args 1 -1))
    "clone" (cli/setup/clone)
    "help" (cli/setup/help (slice args 1 -1))
    (cli/setup/help (slice args 1 -1))))

(defn cli/collections [args]
  (case (first args)
    "add" (cli/collections/add (slice args 1 -1))
    "init" (cli/collections/init (get args 1 nil))
    "deinit" (cli/collections/deinit (get args 1 nil))
    "ls" (cli/collections/ls (get args 1 nil))
    "nuke" (cli/collections/nuke (get args 1 nil))
    "help" (cli/collections/help)
    nil (cli/collections/ls)
    (collections/execute (first args) (slice args 1 -1))))

(defn cli/daemon/sync [args]
  (case (first args)
    "enable" (daemon/sync/enable)
    "disable" (daemon/sync/disable)
    "status" (if (daemon/sync/status) (print "daemon sync enabled") (print "daemon sync disabled"))
    (print `Unknown command, available commands are:
             enable - enable the daemon sync
             disable - disable the daemon sync
             status - show the status of daemon-based sync setting`)))

(defn cli/daemon/status [args]
  (if (daemon/check)
    (do (print "daemon is running") (os/exit 0))
    (do (print "daemon not running") (os/exit 1))))

(defn cli/daemon [args]
  (case (first args)
    "sync" (cli/daemon/sync (slice args 1 -1))
    "status" (cli/daemon/status (slice args 1 -1))
    "ensure" (daemon/ensure)
    "launch" (daemon/launch)
    (print `Unknown command, available commands are:
             sync - configure the daemon-based sync
             launch - launch the daemon
             ensure - ensure the daemon is running
             status - query the status of the daemon`)))

(defn cli/tools [args]
  (case (first args)
    "ensure-pull-merges-submodules" (git/submodules/update/set (util/arch-dir) "merge" :show-message true :recursive true)
    (print `Unknown command! Available commands:
             ensure-pull-merges-submodules - ensure that new commits in submodules are merged in rather than checked out via the submodule.$NAME.update git config option. this is done recursively.`)))

(defn print-root-help []
  (def preinstalled `Available Subcommands:
                      collections - manage your custom collections, use 'glyph collections help' for more information
                      scripts - manage your user scripts
                      git - execute git command on the arch repo
                      sync - sync the glyph archive
                      fsck - perform a filesystem check of arch repo
                      help - print this help`)
  (def collections (map |(string "  " $0 " - " ((collections/get $0) :description)) (collections/ls)))
  (def scripts (map |(string "  " $0 " - user script") (scripts/ls)))
  (print (string/join (array/concat @[preinstalled] collections scripts) "\n")))

(defn main [myself & args]
  (def arch-dir (util/get-arch-dir))
  (unless (let [stat (os/stat arch-dir)] (and stat (= (stat :mode) :directory)))
    (eprint "Arch dir does not exist, please initialize it first!")
    (print "Short setup description:")
    (cli/setup/help [])
    (print "For more information please refer to the glyph documentation")
    (os/exit 1))
  (setdyn :arch-dir arch-dir)
  (case (first args)
    "setup" (cli/setup (slice args 1 -1))
    "store" (cli/store (slcie args 1 -1))
    "status" (git/loud arch-dir "for-each-ref" "--format=%(refname:short) %(upstream:track) %(upstream:remotename)" "refs/heads")
    "collections" (cli/collections (slice args 1 -1))
    "scripts" (print "To add user scripts just add them in the $GLYPH_DIR/scripts directory")
    "daemon" (cli/daemon (slice args 1 -1))
    "git" (os/exit (os/execute ["git" "-C" arch-dir ;(slice args 1 -1)] :p))
    "fsck" (fsck)
    "sync" (sync)
    "tools" (cli/tools (slice args 1 -1))
    "help" (print-root-help)
    "--help" (print-root-help)
    "-h" (print-root-help)
    nil (print-root-help)
    (collections/execute (first args) (slice args 1 -1))))
