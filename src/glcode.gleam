//// This module contains the interface to the Erlang code server, which deals
//// with the loading of compiled code into a running Erlang runtime system.
////
//// The runtime system can be started in interactive or embedded mode. Which
//// one is decided by the command-line flag `-mode`:

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

/// Deletes a directory from the code path. The argument can be an atom Name,
/// in which case the directory with the name .../Name[-Vsn][/ebin] is deleted
/// from the code path. Also, the complete directory name Dir can be specified
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
  /// The module has an -on_load function that failed when it was called.
  EnsureLoadedOnLoadFailure
}

/// Tries to load a module in the same way as `load_file`, unless the module is
/// already loaded. However, in embedded mode it does not load a module that is
/// not already loaded, but returns `Error(EnsureLoadedEmbedded)` instead. See
/// [EnsureLoadedError](#EnsureLoadedError) for a description of other possible error reasons.
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
  /// A previously loaded module contains an -on_load function that never finished.
  AtomicLoadPendingOnLoad(module: String)
  /// The object code resides in a sticky directory.
  AtomicLoadStickyDirectory(module: String)
}

pub type Module {
  ModuleName(String)
  ModuleObject(ObjectCode)
}

@external(erlang, "glcode_ffi", "atomic_load")
pub fn atomic_load(modules: List(Module)) -> Result(Nil, List(AtomicLoadError))

/// Purges the code for Module, that is, removes code marked as old. If some processes still linger in the old code, these processes are killed before the code is removed.
/// Returns true if successful and any process is needed to be killed, otherwise false.
@external(erlang, "glcode_ffi", "purge")
pub fn purge(module: String) -> Bool

/// An opaque term holding prepared code.
pub opaque type Prepared

pub type PrepareLoadingError {
  /// The object code has an incorrect format or the module name in the object code is not the expected module name.
  PrepareLoadingBadFile(module: String)
  /// No file with object code exists.
  PrepareLoadingNoFile(module: String)
  /// A module contains an -on_load function.
  PrepareLoadingOnLoadNotAllowed(module: String)
  /// A module is included more than once in Modules.
  PrepareLoadingDuplicated(module: String)
}

@external(erlang, "glcode_ffi", "prepare_loading")
pub fn prepare_loading(
  modules: List(Module),
) -> Result(Prepared, List(PrepareLoadingError))

pub type FinishLoadingError {
  FinishLoadingNotPurged(module: String)
  FinishLoadingStickyDirectory(module: String)
  FinishLoadingPendingOnLoad(module: String)
}

@external(erlang, "glcode_ffi", "finish_loading")
pub fn finish_loading(
  prepared: Prepared,
) -> Result(Prepared, List(FinishLoadingError))

pub type EnsureModulesLoadedError {
  EnsureModulesLoadedBadfile(module: String)
  EnsureModulesLoadedNofile(module: String)
  EnsureModulesLoadedOnLoadFailure(module: String)
}

/// Tries to load any modules not already loaded in the list Modules in the same way as load_file/1.
/// Returns ok if successful, or {error,[{Module,Reason}]} if loading of some modules fails. See Error Reasons for Code-Loading Functions for a description of other possible error reasons.
@external(erlang, "glcode_ffi", "ensure_modules_loaded")
pub fn ensure_modules_loaded(
  modules: List(String),
) -> Result(Nil, List(EnsureModulesLoadedError))

/// Removes the current code for Module, that is, the current code for Module is made old. This means that processes can continue to execute the code in the module, but no external function calls can be made to it.
/// Returns true if successful, or false if there is old code for Module that must be purged first, or if Module is not a (loaded) module.
@external(erlang, "glcode_ffi", "delete")
pub fn delete(module: String) -> Bool

/// Purges the code for Module, that is, removes code marked as old, but only
/// if no processes linger in it. Returns false if the module cannot be purged
/// because of processes lingering in old code, otherwise true.
@external(erlang, "glcode_ffi", "soft_purge")
pub fn soft_purge(module: String) -> Bool

/// Checks if `module` is loaded. If it is, the loaded filename is returned,
/// otherwise `Error(Nil)`.
/// Normally, Loaded is the absolute filename Filename from which the code is
/// obtained. If the module is preloaded (see script(4)), Loaded==preloaded. If
/// the module is Cover-compiled (see cover(3)), Loaded==cover_compiled.
@external(erlang, "glcode_ffi", "is_loaded")
pub fn is_loaded(module: String) -> Result(String, Nil)

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

// If the module is not loaded, this function searches the code path for the first file containing object code for Module and returns the absolute filename.
// If the module is loaded, it returns the name of the file containing the loaded object code.
// If the module is preloaded, preloaded is returned.
// If the module is Cover-compiled, cover_compiled is returned.
// If the module cannot be found, non_existing is returned.

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

/// lib_dir() -> file:filename()
/// Returns the library directory, $OTPROOT/lib, where $OTPROOT is the root directory of Erlang/OTP.
///
/// Example:
///
/// > code:lib_dir().
/// "/usr/local/otp/lib"
@external(erlang, "glcode_ffi", "lib_dir")
pub fn lib_dir() -> String

pub type LibDirOfError {
  LibDirOfBadName
}

/// lib_dir(Name) -> file:filename() | {error, bad_name}
/// Types
/// Name = atom()
/// Returns the path for the "library directory", the top directory, for an application Name located under $OTPROOT/lib or on a directory referred to with environment variable ERL_LIBS.
///
/// If a regular directory called Name or Name-Vsn exists in the code path with an ebin subdirectory, the path to this directory is returned (not the ebin directory).
///
/// If the directory refers to a directory in an archive, the archive name is stripped away before the path is returned. For example, if directory /usr/local/otp/lib/mnesia-4.2.2.ez/mnesia-4.2.2/ebin is in the path, /usr/local/otp/lib/mnesia-4.2.2/ebin is returned. This means that the library directory for an application is the same, regardless if the application resides in an archive or not.
///
/// Example:
///
/// > code:lib_dir(mnesia).
/// "/usr/local/otp/lib/mnesia-4.2.2"
/// Returns {error, bad_name} if Name is not the name of an application under $OTPROOT/lib or on a directory referred to through environment variable ERL_LIBS. Fails with an exception if Name has the wrong type.
@external(erlang, "glcode_ffi", "lib_dir")
pub fn lib_dir_of(module: String) -> Result(String, LibDirOfError)

/// Returns the path to a subdirectory directly under the top directory of an application. Normally the subdirectories reside under the top directory for the application, but when applications at least partly reside in an archive, the situation is different. Some of the subdirectories can reside as regular directories while others reside in an archive file. It is not checked whether this directory exists.
///
/// Example:
///
/// > code:lib_dir(megaco, priv).
/// "/usr/local/otp/lib/megaco-3.9.1.1/priv"
/// Fails with an exception if Name or SubDir has the wrong type.
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

/// objfile_extension() -> nonempty_string()
/// Returns the object code file extension corresponding to the Erlang machine
/// used, namely .beam.
@external(erlang, "glcode_ffi", "objfile_extension")
pub fn objfile_extension() -> String

/// Marks Dir as sticky.
/// Returns ok if successful, otherwise error.
@external(erlang, "glcode_ffi", "stick_dir")
pub fn stick_dir(dir: String) -> Result(Nil, Nil)

/// Unsticks a directory that is marked as sticky.
/// Returns ok if successful, otherwise error.
@external(erlang, "glcode_ffi", "unstick_dir")
pub fn unstick_dir(dir: String) -> Result(Nil, Nil)

/// Returns true if Module is the name of a module that has been loaded from
/// a sticky directory (in other words: an attempt to reload the module will
/// fail), or false if Module is not a loaded module or is not sticky.
@external(erlang, "glcode_ffi", "is_sticky")
pub fn is_sticky(module: String) -> Bool

pub type WhereIsFileError {
  WhereIsFileNonExisting
}

/// Searches the code path for Filename, a file of arbitrary type. If found, the
/// full name is returned. non_existing is returned if the file cannot be found.
/// The function can be useful, for example, to locate application resource
/// files.
@external(erlang, "glcode_ffi", "where_is_file")
pub fn where_is_file(filename: String) -> Result(String, WhereIsFileError)

/// Searches all directories in the code path for module names with identical
/// names and writes a report to stdout.
@external(erlang, "glcode_ffi", "clash")
pub fn clash() -> Nil

pub type ModuleStatus {
  ModuleStatusNotLoaded(module: String)
  ModuleStatusLoaded(module: String)
  ModuleStatusRemoved(module: String)
  ModuleStatusModified(module: String)
}

// module_status() -> [{module(), module_status()}]
// OTP 23.0
// Types
// module_status() = not_loaded | loaded | modified | removed
// See module_status/1 and all_loaded/0 for details.

// module_status(Module :: module() | [module()]) ->
//                  module_status() | [{module(), module_status()}]
// OTP 20.0
// Types
// module_status() = not_loaded | loaded | modified | removed
// The status of a module can be one of:

// not_loaded
// If Module is not currently loaded.

// loaded
// If Module is loaded and the object file exists and contains the same code.

// removed
// If Module is loaded but no corresponding object file can be found in the code path.

// modified
// If Module is loaded but the object file contains code with a different MD5 checksum.

// Preloaded modules are always reported as loaded, without inspecting the contents on disk. Cover compiled modules will always be reported as modified if an object file exists, or as removed otherwise. Modules whose load path is an empty string (which is the convention for auto-generated code) will only be reported as loaded or not_loaded.

// See also modified_modules/0.
@external(erlang, "glcode_ffi", "module_status")
pub fn module_status(modules: List(String)) -> List(ModuleStatus)

/// Returns the list of all currently loaded modules for which module_status/1
/// returns modified. See also `all_loaded`.
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
/// server is in embedded mode, the code must be loaded with `load_binary`.
@external(erlang, "code", "get_mode")
pub fn get_mode() -> Mode
