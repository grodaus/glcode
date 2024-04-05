-module(glcode_ffi).
-export([
    add_pathz/1,
    add_patha/1,
    add_pathsz/1,
    add_pathsa/1,
    del_path/1,
    replace_path/2,
    load_file/1,
    load_abs/1,
    ensure_loaded/1,
    load_binary/3,
    get_object_code/1,
    atomic_load/1,
    purge/1,
    prepare_loading/1,
    finish_loading/1,
    ensure_modules_loaded/1,
    delete/1,
    soft_purge/1,
    is_loaded/1,
    all_available/0,
    all_loaded/0,
    which/1,
    get_doc/1,
    root_dir/0,
    lib_dir/0,
    lib_dir/1,
    lib_dir/2,
    compiler_dir/0,
    priv_dir/1,
    objfile_extension/0,
    stick_dir/1,
    unstick_dir/1,
    is_sticky/1,
    where_is_file/1,
    clash/0,
    module_status/1,
    modified_modules/0
]).

add_pathz(Dir) ->
    case code:add_pathz(binary:bin_to_list(Dir)) of
        true -> {ok, nil};
        Error -> Error
    end.

add_patha(Dir) ->
    case code:add_patha(binary:bin_to_list(Dir)) of
        true -> {ok, nil};
        Error -> Error
    end.

add_pathsz(Dirs) ->
    case code:add_pathsz(lists:map(fun binary:bin_to_list/1, Dirs)) of
        ok -> nil
    end.

add_pathsa(Dirs) ->
    case code:add_pathsa(lists:map(fun binary:bin_to_list/1, Dirs)) of
        ok -> nil
    end.

del_path(Dir) ->
    Arg =
        case Dir of
            {path, Path} -> binary:bin_to_list(Path);
            {name, Name} -> erlang:binary_to_atom(Name)
        end,
    case code:del_path(Arg) of
        true -> {ok, nil};
        false -> {error, delete_path_not_found};
        {error, bad_name} -> {error, delete_path_bad_name}
    end.

replace_path(Name, Dir) ->
    case code:replace_path(erlang:binary_to_atom(Name), binary:bin_to_list(Dir)) of
        true ->
            {ok, nil};
        {error, bad_name} ->
            {error, replace_path_bad_name};
        {error, bad_directory} ->
            {error, replace_path_bad_directory};
        {error, {badarg, [Name_, Dir_]}} ->
            {error,
                {replace_path_bad_argument, erlang:atom_to_binary(Name_), binary:list_to_bin(Dir_)}}
    end.

load_file(Module) ->
    case code:load_file(erlang:binary_to_atom(Module)) of
        {module, Module_} ->
            {ok, erlang:atom_to_binary(Module_)};
        {error, Error} ->
            {error, load_errors(Error)}
    end.

load_abs(Filename) ->
    case code:load_abs(erlang:binary_to_list(Filename)) of
        {module, Module_} ->
            {ok, erlang:atom_to_binary(Module_)};
        {error, Error} ->
            {error, load_errors(Error)}
    end.

ensure_loaded(Module) ->
    case code:load_file(erlang:binary_to_atom(Module)) of
        {module, Module_} ->
            {ok, erlang:atom_to_binary(Module_)};
        {error, Error} ->
            {error, load_errors(Error)}
    end.

load_errors(Error) ->
    case Error of
        badarg -> load_file_bad_argument;
        badfile -> load_file_bad_file;
        nofile -> load_file_no_file;
        not_purged -> load_file_not_purged;
        on_load_failure -> load_file_on_load_failure;
        sticky_directory -> load_file_sticky_directory
    end.

load_binary(Module, Filename, Binary) ->
    case
        code:load_binary(
            erlang:binary_to_atom(Module),
            erlang:binary_to_list(Filename),
            Binary
        )
    of
        {module, Module_} -> {ok, erlang:atom_to_binary(Module_)};
        {error, Error} -> {error, load_errors(Error)}
    end.

get_object_code(Module) ->
    case code:get_object_code(erlang:binary_to_atom(Module)) of
        {Module_, Binary, Filename} ->
            {ok, {object, erlang:atom_to_binary(Module_), Binary, erlang:list_to_binary(Filename)}};
        {error, Error} ->
            {error, load_errors(Error)}
    end.

atomic_load(Modules) ->
    case code:atomic_load(modules_prep(Modules)) of
        ok -> {ok, nil};
        {error, Modules_} -> {error, lists:map(fun atomic_load_error/1, Modules_)}
    end.

modules_prep(Modules) ->
    lists:map(fun module_prep/1, Modules).

module_prep(Module) ->
    case Module of
        {module_name, Name} ->
            erlang:binary_to_atom(Name);
        {module_object, {object, {Module, Binary, Filename}}} ->
            {erlang:binary_to_atom(Module), erlang:binary_to_list(Filename), Binary};
        Name ->
            erlang:binary_to_atom(Name)
    end.

atomic_load_error({Module, What}) ->
    Module_ = erlang:atom_to_binary(Module),
    What_ =
        case What of
            badfile -> atomic_load_bad_file;
            nofile -> atomic_load_no_file;
            on_load_not_allowed -> atomic_load_on_load_not_allowed;
            duplicated -> atomic_load_duplicated;
            not_purged -> atomic_load_not_purged;
            sticky_directory -> atomic_load_sticky_directory;
            pending_on_load -> atomic_load_pending_on_load
        end,
    {What_, Module_}.

purge(Module) ->
    code:purge(erlang:binary_to_atom(Module)).

prepare_loading(Modules) ->
    case code:prepare_loading(modules_prep(Modules)) of
        {ok, Prepared} -> {ok, Prepared};
        {error, Error} -> {error, lists:map(fun prepare_loading_error/1, Error)}
    end.

prepare_loading_error({Module, What}) ->
    Module_ = erlang:atom_to_binary(Module),
    What_ =
        case What of
            badfile -> prepare_loading_bad_file;
            nofile -> prepare_loading_no_file;
            on_load_not_allowed -> prepare_loading_on_load_not_allowed;
            duplicated -> prepare_loading_duplicated
        end,
    {What_, Module_}.

finish_loading(Prepared) ->
    case code:finish_loading(Prepared) of
        ok -> {ok, nil};
        {error, Error} -> {error, lists:map(fun finish_loading_error/1, Error)}
    end.

finish_loading_error({Module, What}) ->
    Module_ = erlang:atom_to_binary(Module),
    What_ =
        case What of
            not_purged -> finish_loading_not_purged;
            sticky_directory -> finish_loading_sticky_directory;
            pending_on_load -> finish_loading_pending_on_load
        end,
    {What_, Module_}.

ensure_modules_loaded(Modules) ->
    case code:ensure_modules_loaded(modules_prep(Modules)) of
        ok -> {ok, nil};
        {error, Error} -> {error, lists:map(fun ensure_modules_loaded_error/1, Error)}
    end.

ensure_modules_loaded_error({Module, What}) ->
    Module_ = erlang:atom_to_binary(Module),
    What_ =
        case What of
            badfile -> ensure_modules_loaded_bad_file;
            nofile -> ensure_modules_loaded_no_file;
            on_load_failure -> ensure_modules_loaded_on_load_failure
        end,
    {What_, Module_}.

delete(Module) ->
    code:delete(erlang:binary_to_atom(Module)).

soft_purge(Module) ->
    code:soft_purge(erlang:binary_to_atom(Module)).

is_loaded(Module) ->
    case code:is_loaded(erlang:binary_to_atom(Module)) of
        cover_compiled -> {ok, is_cover_compiled};
        preloaded -> {ok, is_preloaded};
        {file, Filename} -> {ok, erlang:list_to_binary(Filename)};
        false -> {error, nil}
    end.

all_available() ->
    lists:map(fun map_all_available/1, code:all_available()).

map_all_available({Module, Filename, Loaded}) ->
    Module_ = erlang:list_to_binary(Module),
    case Filename of
        cover_compiled -> {available_cover_compiled, Module_, Loaded};
        preloaded -> {available_preloaded, Module_, Loaded};
        Filename -> {available, Module_, erlang:list_to_binary(Filename), Loaded}
    end.

all_loaded() ->
    lists:map(fun map_all_loaded/1, code:all_loaded()).

map_all_loaded({Module, Loaded}) ->
    Module_ = erlang:atom_to_binary(Module),
    case Loaded of
        preloaded -> {loaded_preloaded, Module_};
        cover_compiled -> {loaded_cover_compiled, Module_};
        _ -> {loaded, Module_, erlang:list_to_binary(Loaded)}
    end.

which(Module) ->
    case code:which(erlang:binary_to_atom(Module)) of
        preloaded -> {ok, which_preloaded};
        cover_compiled -> {ok, which_cover_compiled};
        non_existing -> {error, which_non_existing};
        Other -> {ok, {which_filename, erlang:list_to_binary(Other)}}
    end.

get_doc(Module) ->
    case code:get_doc(erlang:binary_to_atom(Module)) of
        {ok, Res} ->
            {ok, Res};
        {error, Reason} ->
            case Reason of
                non_existing -> {error, get_doc_non_existing};
                missing -> {error, get_doc_missing};
                Posix -> {error, {get_doc_posix, erlang:atom_to_binary(Posix)}}
            end
    end.

root_dir() ->
    erlang:list_to_binary(code:root_dir()).

lib_dir() ->
    erlang:list_to_binary(code:lib_dir()).

lib_dir(Module) ->
    case erlang:list_to_binary(code:lib_dir(erlang:binary_to_atom(Module))) of
        {error, bad_name} -> {error, lib_dir_of_bad_name};
        Filename -> {ok, Filename}
    end.

lib_dir(Module, Dir) ->
    case code:lib_dir(erlang:binary_to_atom(Module), erlang:binary_to_atom(Dir)) of
        {error, bad_name} -> {error, lib_dir_of_bad_name};
        Filename -> {ok, erlang:list_to_binary(Filename)}
    end.

compiler_dir() ->
    erlang:list_to_binary(code:compiler_dir()).

priv_dir(Module) ->
    case code:priv_dir(erlang:binary_to_atom(Module)) of
        {error, badfile} -> {error, bad_file};
        Dir -> {ok, erlang:list_to_binary(Dir)}
    end.

objfile_extension() ->
    erlang:list_to_binary(code:objfile_extension()).

stick_dir(Dir) ->
    case code:stick_dir(erlang:binary_to_list(Dir)) of
        ok -> {ok, nil};
        error -> {error, nil}
    end.

unstick_dir(Dir) ->
    case code:unstick_dir(erlang:binary_to_list(Dir)) of
        ok -> {ok, nil};
        error -> {error, nil}
    end.

is_sticky(Module) ->
    code:is_sticky(erlang:binary_to_atom(Module)).

where_is_file(Filename) ->
    case code:where_is_file(erlang:binary_to_list(Filename)) of
        non_existing -> {error, where_is_file_non_existing};
        Absname -> {ok, erlang:list_to_binary(Absname)}
    end.

clash() ->
    case code:clash() of
        ok -> nil
    end.

module_status(Modules) ->
    Status = code:module_status(lists:map(fun erlang:binary_to_atom/1, Modules)),
    lists:map(fun map_module_status/1, Status).

map_module_status({Name, Status}) ->
    Name_ = erlang:atom_to_binary(Name),
    case Status of
        not_loaded -> {module_status_not_loaded, Name_};
        loaded -> {module_status_loaded, Name_};
        removed -> {module_status_removed, Name_};
        modified -> {module_status_modified, Name_};
        Other -> Other
    end.

modified_modules() ->
    lists:map(fun convert_modified_module/1, code:modified_modules()).

convert_modified_module(Module) ->
    Name = erlang:atom_to_binary(Module),
    {module_name, Name}.
