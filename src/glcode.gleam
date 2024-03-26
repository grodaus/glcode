//// This module contains the interface to the Erlang code server, which deals
//// with the loading of compiled code into a running Erlang runtime system.
////
//// The runtime system can be started in interactive or embedded mode. Which
//// one is decided by the command-line flag `-mode`:
////
////     erl -mode interactive
////
//// The modes are as follows:
////
//// * In interactive mode, which is default, only some code is loaded during
////   system startup, basically the modules needed by the runtime system.
////   Other code is dynamically loaded when first referenced. When a call to a
////   function in a certain module is made, and the module is not loaded, the
////   code server searches for and tries to load the module.
////
//// * In embedded mode, modules are not auto loaded. Trying to use a module
////   that has not been loaded results in an error. This mode is recommended
////   when the boot script loads all modules, as it is typically done in OTP
////   releases. (Code can still be loaded later by explicitly ordering the code
////   server to do so).
////
//// To prevent accidentally reloading of modules affecting the Erlang runtime
//// system, directories `kernel`, `stdlib`, and `compiler` are considered
//// *sticky*. This means that the system issues a warning and rejects the
//// request if a user tries to reload a module residing in any of them. The
//// feature can be disabled by using command-line flag `-nostick`.
////
//// ## Code Path
////
//// In interactive mode, the code server maintains a search path, usually
//// called the code path, consisting of a list of directories, which it
//// searches sequentially when trying to load a module.
//// 
//// Initially, the code path consists of the current working directory and
//// all Erlang object code directories under library directory `$OTPROOT/lib`,
//// where `$OTPROOT` is the installation directory of Erlang/OTP, `root_dir()`.
//// Directories can be named `Name[-Vsn]` and the `code` server, by default,
//// chooses the directory with the highest version number among those having
//// the same Name. Suffix `-Vsn` is optional. If an ebin directory exists under
//// `Name[-Vsn]`, this directory is added to the code path.
//// 
//// Environment variable `ERL_LIBS` (defined in the operating system) can be
//// used to define more library directories to be handled in the same way as
//// the standard OTP library directory described above, except that directories
//// without an ebin directory are ignored.
//// 
//// All application directories found in the additional directories appear
//// before the standard OTP applications, except for the Kernel and STDLIB
//// applications, which are placed before any additional applications. In other
//// words, modules found in any of the additional library directories override
//// modules with the same name in OTP, except for modules in Kernel and STDLIB.
//// 
//// Environment variable `ERL_LIBS` (if defined) is to contain a
//// colon-separated (for Unix-like systems) or semicolon-separated (for
//// Windows) list of additional libraries.
//// 
//// ### Example:
//// 
//// On a Unix-like system, `ERL_LIBS` can be set to the following
//// 
////     /usr/local/jungerl:/home/some_user/my_erlang_lib
////
//// On Windows, use semi-colon as separator.
//// 
//// ## Current and Old Code
////
//// The code for a module can exist in two variants in a system: *current code*
//// and *old code*. When a module is loaded into the system for the first time,
//// the module code becomes 'current' and the global export table is updated
//// with references to all functions exported from the module.
//// 
//// If then a new instance of the module is loaded (for example, because of
//// error correction), the code of the previous instance becomes 'old', and all
//// export entries referring to the previous instance are removed. After that,
//// the new instance is loaded as for the first time, and becomes 'current'.
//// 
//// Both old and current code for a module are valid, and can even be evaluated
//// concurrently. The difference is that exported functions in old code are
//// unavailable. Hence, a global call cannot be made to an exported function
//// in old code, but old code can still be evaluated because of processes
//// lingering in it.
//// 
//// If a third instance of the module is loaded, the code server removes
//// (purges) the old code and any processes lingering in it are terminated.
//// Then the third instance becomes 'current' and the previously current code
//// becomes 'old'.
//// 
//// For more information about old and current code, and how to make a
//// process switch from old to current code, see section "Compilation and
//// Code Loading" in the
//// [Erlang Reference Manual](https://www.erlang.org/doc/reference_manual/code_loading).

import gleam/dynamic.{type Dynamic}

pub type LoadError {
  /// The object code has an incorrect format or the module name in the object code is not the expected module name.
  LoadFileBadFile
  /// No file with object code was found.
  LoadFileNoFile
  /// The object code could not be loaded because an old version of the code already existed.
  LoadFileNotPurged
  /// The module has an -on_load function that failed when it was called.
  LoadFileOnLoadFailure
  /// The object code resides in a sticky directory.
  LoadFileStickyDirectory
  /// name or dir is invalid
  LoadFileBadArg
}

pub type AddPathError {
  /// given dir is not a directory
  AddPathBadDirectory
}

pub type DeletePathError {
  /// given dir is invalid
  DeletePathBadName
  /// given dir is wasn't found
  DeletePathNotFound
}

pub type ReplacePathError {
  /// If Name is not found
  ReplacePathBadName
  /// If `dir` does not exist
  ReplacePathBadDirectory
  /// If `name` or `dir` is invalid
  ReplacePathBadArgument(name: String, dir: String)
}

pub type PathOrName {
  Path(String)
  Name(String)
}

/// Adds `dir` to the code path. The directory is added as the last directory in
/// the new path. If the directory already exists in the path, it is not added.
@external(erlang, "glcode_ffi", "add_pathz")
pub fn append_path(dir: String) -> Result(Nil, AddPathError)

/// Adds `dir` to the beginning of the code path. If the directory already
/// exists, it is removed from the old position in the code path.
@external(erlang, "glcode_ffi", "add_patha")
pub fn prepend_path(dir: String) -> Result(Nil, AddPathError)

/// Adds the directories in `dirs` to the end of the code path. If a already
/// directory exists, it is not added.
@external(erlang, "glcode_ffi", "add_pathsz")
pub fn append_paths(dirs: List(String)) -> Nil

/// Traverses `dirs` and adds each directory to the beginning of the code path.
/// This means that the order of `dirs` is reversed in the resulting code path.
/// For example, if you add `[dir1, dir2]`, the resulting path will be
/// `[dir2, dir1, ..old_code_path]`.
/// If a directory already exists in the code path, it is removed from the old
/// position.
@external(erlang, "glcode_ffi", "add_pathsa")
pub fn prepend_paths(dirs: List(String)) -> Nil

/// Deletes a directory from the code path. The argument can be a `Name`, in
/// which case the directory with the name `.../Name[-Vsn][/ebin]` is deleted
/// from the code path. Also, the complete directory `Path` can be specified
/// as argument.
@external(erlang, "glcode_ffi", "del_path")
pub fn delete_path(dir: PathOrName) -> Result(Nil, DeletePathError)

/// Replaces an old occurrence of a directory named `.../Name[-Vsn][/ebin]` in the
/// code path, with `dir`. If `name` does not exist, it adds the new directory `dir`
/// last in the code path. The new directory must also be named
/// `.../Name[-Vsn][/ebin]`. This function is to be used if a new version of the
/// directory (library) is added to a running system.
@external(erlang, "glcode_ffi", "replace_path")
pub fn replace_path(name: String, dir: String) -> Result(Nil, ReplacePathError)

/// Tries to load the Erlang module `module`, using the code path. It looks for
/// the object code file with an extension corresponding to the Erlang machine
/// used, for example, `module`.beam. The loading fails if the module name found
/// in the object code differs from the name `module`. `load_binary` must be
/// used to load object code with a module name that is different from the file
/// name.
@external(erlang, "glcode_ffi", "load_file")
pub fn load_file(name: String) -> Result(String, LoadError)

/// Same as `load_file`, but `filename` is an absolute or relative filename.
/// The code path is not searched. It returns a value in the same way as
/// `load_file`. Notice that Filename must not contain the extension (for
/// example, `.beam`) because `load_abs` adds the correct extension.
@external(erlang, "glcode_ffi", "load_abs")
pub fn load_abs(filename: String) -> Result(String, LoadError)

pub type EnsureLoadedError {
  /// modules cannot be loaded in embedded mode
  EnsureLoadedEmbedded
  /// The object code has an incorrect format or the module name in the object
  /// code is not the expected module name.
  EnsureLoadedBadFile
  /// No file with object code was found.
  EnsureLoadedNoFile
  /// The module has an `-on_load` function that failed when it was called.
  EnsureLoadedOnLoadFailure
}

/// Tries to load a module in the same way as `load_file`, unless the module is
/// already loaded. However, in embedded mode it does not load a module that is
/// not already loaded, but returns [`EnsureLoadedEmbedded`](#EnsureLoadedEmbedded)
/// instead. See [`EnsureLoadedError`](#EnsureLoadedError) for a description of
/// other possible error reasons.
@external(erlang, "glcode_ffi", "ensure_loaded")
pub fn ensure_loaded(module: String) -> Result(String, EnsureLoadedError)

/// This function can be used to load object code on remote Erlang nodes.
/// Argument `binary` must contain object code for `module`. `filename` is only
/// used by the code server to keep a record of from which file the object code
/// for `module` comes. Thus, `filename` is not opened and read by the code
/// server.
@external(erlang, "glcode_ffi", "load_binary")
pub fn load_binary(
  module: String,
  filename: String,
  binary: BitArray,
) -> Result(String, LoadError)

pub type ObjectCode {
  Object(module: String, binary: BitArray, filename: String)
}

/// This function can be used to load object code on remote Erlang nodes.
/// Argument `binary` must contain object code for `module`. `filename` is only
/// used by the code server to keep a record of from which file the object code
/// for `module` comes. Thus, `filename` is not opened and read by the code
/// server.
@external(erlang, "glcode_ffi", "get_object_code")
pub fn get_object_code(module: String) -> Result(ObjectCode, LoadError)

pub type AtomicLoadError {
  /// The object code has an incorrect format or the module name in the object code is not the expected module name.
  AtomicLoadBadFile(module: String)
  /// A module is included more than once in Modules.
  AtomicLoadDuplicated(module: String)
  /// No file with object code exists.
  AtomicLoadNoFile(module: String)
  /// The object code cannot be loaded because an old version of the code already exists.
  AtomicLoadNotPurged(module: String)
  /// A module contains an -on_load function.
  AtomicLoadOnLoadNotAllowed(module: String)
  /// A previously loaded module contains an `-on_load` function that never finished.
  AtomicLoadPendingOnLoad(module: String)
  /// The object code resides in a sticky directory.
  AtomicLoadStickyDirectory(module: String)
}

pub type Module {
  ModuleName(String)
  ModuleObject(ObjectCode)
}

/// Tries to load all of the modules in the list `modules` atomically. That
/// means that either all modules are loaded at the same time, or none of the
/// modules are loaded if there is a problem with any of the modules.
///
/// If it is important to minimize the time that an application is inactive
/// while changing code, use [`prepare_loading`](#prepare_loading) and
/// [`finish_loading`](#finish_loading) instead of `atomic_load`. Here is an
/// example:
///
///     let assert Ok(prepared) = glcode.prepare_loading(["module1", "module2"])
///     // Put the application into an inactive state or do any other
///     // preparation needed before changing the code.
///     let assert Ok(Nil) = glcode.finish_loading(Prepared)
///     // Resume the application.
@external(erlang, "glcode_ffi", "atomic_load")
pub fn atomic_load(modules: List(Module)) -> Result(Nil, List(AtomicLoadError))

/// Purges the code for Module, that is, removes code marked as old. If some processes still linger in the old code, these processes are killed before the code is removed.
/// Returns true if successful and any process is needed to be killed, otherwise false.
@external(erlang, "glcode_ffi", "purge")
pub fn purge(module: String) -> Bool

/// An opaque term holding prepared code.
pub opaque type Prepared

pub type PrepareLoadingError {
  /// The object code has an incorrect format or the module name in the object
  /// code is not the expected module name.
  PrepareLoadingBadFile(module: String)
  /// No file with object code exists.
  PrepareLoadingNoFile(module: String)
  /// A module contains an `-on_load` function.
  PrepareLoadingOnLoadNotAllowed(module: String)
  /// A module is included more than once in `modules`.
  PrepareLoadingDuplicated(module: String)
}

/// Prepares to load the modules in the list `modules`. Finish the loading by
/// calling [`finish_loading(prepared)`](#finish_loading).
@external(erlang, "glcode_ffi", "prepare_loading")
pub fn prepare_loading(
  modules: List(Module),
) -> Result(Prepared, List(PrepareLoadingError))

pub type FinishLoadingError {
  /// The object code cannot be loaded because an old version of the code
  /// already exists.
  FinishLoadingNotPurged(module: String)
  /// The object code resides in a sticky directory.
  FinishLoadingStickyDirectory(module: String)
  /// A previously loaded module contains an `-on_load` function that never
  /// finished.
  FinishLoadingPendingOnLoad(module: String)
}

/// Tries to load code for all modules that have been previously prepared
/// by [`prepare_loading`](#prepare_loading). The loading occurs atomically,
/// meaning that either all modules are loaded at the same time, or none of the
/// modules are loaded.
@external(erlang, "glcode_ffi", "finish_loading")
pub fn finish_loading(
  prepared: Prepared,
) -> Result(Nil, List(FinishLoadingError))

pub type EnsureModulesLoadedError {
  EnsureModulesLoadedBadfile(module: String)
  EnsureModulesLoadedNofile(module: String)
  EnsureModulesLoadedOnLoadFailure(module: String)
}

/// Tries to load any modules not already loaded in the list `modules` in the
/// same way as [`load_file`](#load_file).
@external(erlang, "glcode_ffi", "ensure_modules_loaded")
pub fn ensure_modules_loaded(
  modules: List(String),
) -> Result(Nil, List(EnsureModulesLoadedError))

/// Removes the current code for `module`, that is, the current code for
/// `module` is made old. This means that processes can continue to execute the
/// code in the module, but no external function calls can be made to it.
///
/// Returns `True` if successful, or `False` if there is old code for `module`
/// that must be purged first, or if `module` is not a (loaded) module.
@external(erlang, "glcode_ffi", "delete")
pub fn delete(module: String) -> Bool

/// Purges the code for `Module`, that is, removes code marked as old, but only
/// if no processes linger in it. Returns `False` if the module cannot be purged
/// because of processes lingering in old code, otherwise `True`.
@external(erlang, "glcode_ffi", "soft_purge")
pub fn soft_purge(module: String) -> Bool

pub type IsLoaded {
  IsLoaded(filename: String)
  IsPreloaded
  IsCoverCompiled
}

/// Checks if `module` is loaded. If it is, the loaded filename is returned,
/// otherwise `Error(Nil)`.
/// Normally, `IsLoaded` contains the the absolute `filename` from which the code is
/// obtained. If the module is preloaded (see
/// [script(4)](https://www.erlang.org/doc/man/script)
/// ), then it returns `IsPreloaded`. If
/// the module is Cover-compiled (see
/// [cover(3)](https://www.erlang.org/doc/man/cover)
/// ), it returns `IsCoverCompiled`.
@external(erlang, "glcode_ffi", "is_loaded")
pub fn is_loaded(module: String) -> Result(IsLoaded, Nil)

pub type Available {
  /// `filename` is normally the absolute filename, as described for
  /// `is_loaded`.
  Available(module: String, filename: String, loaded: Bool)
  AvailablePreloaded(module: String, loaded: Bool)
  AvailableCoverCompiled(module: String, loaded: Bool)
}

/// Returns a list of all available modules. A module is considered to be
/// available if it either is loaded or would be loaded if called.
@external(erlang, "glcode_ffi", "all_available")
pub fn all_available() -> List(Available)

pub type Loaded {
  Loaded(module: String, filepath: String)
  LoadedPreloaded(module: String)
  LoadedCoverCompiled(module: String)
}

/// Returns a list of all loaded modules.
@external(erlang, "glcode_ffi", "all_loaded")
pub fn all_loaded() -> List(Loaded)

pub type Which {
  WhichPreloaded
  WhichCoverCompiled
  WhichFilename(filename: String)
}

pub type WhichError {
  WhichNonExisting
}

/// If the module is not loaded, this function searches the code path for
/// the first file containing object code for `module` and returns the absolute
/// filename.
///
/// If the module is loaded, it returns the name of the file containing the
/// loaded object code.
///
/// If the module is preloaded, `WhichPreloaded` is returned.
///
/// If the module is Cover-compiled, `WhichCoverCompiled` is returned.
///
/// If the module cannot be found, `WhichNonExisting` is returned.
///
@external(erlang, "glcode_ffi", "which")
pub fn which(module: String) -> Result(Which, WhichError)

pub type GetDocError {
  GetDocNonExisting
  GetDocMissing
  GetDocPosix(error: String)
}

/// Searches the code path for EEP-48 style documentation and returns it if
/// available. If no documentation can be found the function tries to generate
/// documentation from the debug information in the module.
///
/// For more information about the documentation chunk see Documentation Storage
/// and Format in Kernel's User's Guide.
///
/// For now this returns a dynamic value since coming up with a sensible Gleam
/// type for it is crazy.
@external(erlang, "glcode_ffi", "get_doc")
pub fn get_doc(module: String) -> Result(Dynamic, GetDocError)

/// root_dir() -> file:filename()
/// Returns the root directory of Erlang/OTP, which is the directory where it is installed.
/// Example:
/// > code:root_dir().
/// "/usr/local/otp"
@external(erlang, "glcode_ffi", "root_dir")
pub fn root_dir() -> String

/// Returns the library directory, `$OTPROOT/lib`, where `$OTPROOT` is the root
/// directory of Erlang/OTP.
///
/// ### Example:
///
///     glcode.lib_dir()
///     "/nix/store/gnm9kc4qnayb7wbhmnsq0w6yqgh7xgn3-erlang-25.3.2.9/lib/erlang/lib"
@external(erlang, "glcode_ffi", "lib_dir")
pub fn lib_dir() -> String

pub type LibDirOfError {
  LibDirOfBadName
}

/// Returns the path for the "library directory", the top directory, for an
/// application Name located under `$OTPROOT/lib` or on a directory referred to
/// with environment variable `ERL_LIBS`.
///
/// If a regular directory called `name` or `name-Vsn` exists in the code
/// path with an `ebin` subdirectory, the path to this directory is returned
/// (not the ebin directory).
/// If the directory refers to a directory in an archive, the archive name is
/// stripped away before the path is returned. For example, if directory `/usr/
/// local/otp/lib/mnesia-4.2.2.ez/mnesia-4.2.2/ebin` is in the path, `/usr/local/
/// otp/lib/mnesia-4.2.2/ebin` is returned. This means that the library directory
/// for an application is the same, regardless if the application resides in an
/// archive or not.
///
/// ### Example:
///
///     > glcode.lib_dir("mnesia")
///     "/nix/store/gnm9kc4qnayb7wbhmnsq0w6yqgh7xgn3-erlang-25.3.2.9/lib/erlang/lib/mnesia-4.21.4.2"
///
/// Returns an error if `name` is not the name of an application under
/// `$OTPROOT/lib` or on a directory referred to through environment variable
/// `ERL_LIBS`.
@external(erlang, "glcode_ffi", "lib_dir")
pub fn lib_dir_of(name: String) -> Result(String, LibDirOfError)

/// Returns the path to a subdirectory directly under the top directory of an application. Normally the subdirectories reside under the top directory for the application, but when applications at least partly reside in an archive, the situation is different. Some of the subdirectories can reside as regular directories while others reside in an archive file. It is not checked whether this directory exists.
///
/// Example:
///
///     > glcode.lib_dir("megaco", "priv").
///     "/usr/local/otp/lib/megaco-3.9.1.1/priv"
@external(erlang, "glcode_ffi", "lib_dir")
pub fn lib_dir_of_sub(
  module: String,
  dir: String,
) -> Result(String, LibDirOfError)

/// Returns the compiler library directory. Equivalent to `lib_dir("compiler")`.
@external(erlang, "glcode_ffi", "compiler_dir")
pub fn compiler_dir() -> String

/// Returns the path to the priv directory in an application. Equivalent to
/// `lib_dir(name, "priv")`.
@external(erlang, "glcode_ffi", "priv_dir")
pub fn priv_dir(name: String) -> Result(Nil, String)

/// Returns the object code file extension corresponding to the Erlang machine
/// used, namely `.beam`.
@external(erlang, "glcode_ffi", "objfile_extension")
pub fn objfile_extension() -> String

/// Marks `dir` as sticky.
@external(erlang, "glcode_ffi", "stick_dir")
pub fn stick_dir(dir: String) -> Result(Nil, Nil)

/// Unsticks a directory that is marked as sticky.
@external(erlang, "glcode_ffi", "unstick_dir")
pub fn unstick_dir(dir: String) -> Result(Nil, Nil)

/// Returns `True` if `module` is the name of a module that has been loaded from
/// a sticky directory (in other words: an attempt to reload the module will
/// fail), or `False` if `module` is not a loaded module or is not sticky.
@external(erlang, "glcode_ffi", "is_sticky")
pub fn is_sticky(module: String) -> Bool

pub type WhereIsFileError {
  /// is returned if the file cannot be found
  WhereIsFileNonExisting
}

/// Searches the code path for `filename`, a file of arbitrary type. If found,
/// the full name is returned. The function can be useful, for example, to
/// locate application resource files.
@external(erlang, "glcode_ffi", "where_is_file")
pub fn where_is_file(filename: String) -> Result(String, WhereIsFileError)

/// Searches all directories in the code path for module names with identical
/// names and writes a report to `stdout`.
@external(erlang, "glcode_ffi", "clash")
pub fn clash() -> Nil

pub type ModuleStatus {
  /// If `module` is not currently loaded
  ModuleStatusNotLoaded(module: String)
  /// If `module` is loaded and the object file exists and contains the same code
  ModuleStatusLoaded(module: String)
  /// If `module` is loaded but no corresponding object file can be found in the code path
  ModuleStatusRemoved(module: String)
  /// If `module` is loaded but the object file contains code with a different MD5 checksum
  ModuleStatusModified(module: String)
}

// See also [modified_modules](#modified_modules).
/// Preloaded modules are always reported as loaded, without inspecting the
/// contents on disk. Cover compiled modules will always be reported as modified
/// if an object file exists, or as removed otherwise. Modules whose load path
/// is an empty string (which is the convention for auto-generated code) will
/// only be reported as Loaded or NotLoaded.
@external(erlang, "glcode_ffi", "module_status")
pub fn module_status(modules: List(String)) -> List(ModuleStatus)

/// Returns the list of all currently loaded modules for which
/// [`module_status`](#module_status)
/// returns modified. See also [`all_loaded`](#all_loaded).
@external(erlang, "glcode_ffi", "modified_modules")
pub fn modified_modules() -> List(ModuleStatus)

pub type Mode {
  Interactive
  Embedded
}

/// Returns an atom describing the mode of the code server: interactive or
/// embedded. This information is useful when an external entity (for example,
/// an IDE) provides additional code for a running node. If the code server is
/// in interactive mode, it only has to add the path to the code. If the code
/// server is in embedded mode, the code must be loaded with
/// [`load_binary`](#load_binary).
@external(erlang, "code", "get_mode")
pub fn get_mode() -> Mode
