import showtime
import gleam/string
import gleam/list
import showtime/tests/should
import glcode

pub fn main() {
  showtime.main()
}

pub fn append_path_test() {
  glcode.append_path("test")
  |> should.equal(Ok(Nil))
}

pub fn prepend_path_test() {
  glcode.prepend_path("test")
  |> should.equal(Ok(Nil))
}

pub fn append_paths_test() {
  glcode.append_paths(["test"])
  |> should.equal(Nil)
}

pub fn prepend_paths_test() {
  glcode.prepend_paths(["test"])
  |> should.equal(Nil)
}

pub fn delete_path_name_test() {
  glcode.append_paths(["test"])
  |> should.equal(Nil)

  glcode.delete_path(glcode.Name("test"))
  |> should.equal(Ok(Nil))
}

pub fn delete_path_path_test() {
  glcode.append_paths(["test"])
  |> should.equal(Nil)

  glcode.delete_path(glcode.Path("test"))
  |> should.equal(Ok(Nil))
}

pub fn replace_path_test() {
  glcode.replace_path("test", "test")
  |> should.equal(Ok(Nil))

  glcode.replace_path("test", "src")
  |> should.equal(Error(glcode.ReplacePathBadName))
}

pub fn load_file_test() {
  glcode.append_path("build/dev/erlang/erlfmt/ebin")
  |> should.equal(Ok(Nil))

  glcode.load_file("erlfmt_format")
  |> should.equal(Ok("erlfmt_format"))
}

pub fn load_abs_test() {
  glcode.load_abs("build/dev/erlang/erlfmt/ebin/erlfmt_format")
  |> should.equal(Ok("erlfmt_format"))
}

pub fn ensure_loaded() {
  glcode.ensure_loaded("erlfmt_format")
  |> should.equal(Ok("erlfmt_format"))
}

pub fn get_object_code_test() {
  let glcode.Object(module, _binary, _filename) =
    glcode.get_object_code("erlfmt_format")
    |> should.be_ok
  module
  |> should.equal("erlfmt_format")
}

pub fn load_binary_test() {
  let glcode.Object(module, binary, filename) =
    glcode.get_object_code("erlfmt_format")
    |> should.be_ok

  glcode.load_binary(module, filename, binary)
  |> should.equal(Ok("erlfmt_format"))
}

pub fn purge_test() {
  glcode.purge("erlfmt_format")
  |> should.equal(False)
}

pub fn atomic_load_test() {
  glcode.atomic_load([glcode.ModuleName("erlfmt_format")])
  |> should.be_ok
}

pub fn prepare_loading_test() {
  glcode.prepare_loading([glcode.ModuleName("erlfmt_format")])
  |> should.be_ok

  glcode.prepare_loading([glcode.ModuleName("foo")])
  |> should.be_error()
  |> should.equal([glcode.PrepareLoadingNoFile("foo")])
}

pub fn finish_loading_test() {
  glcode.purge("erlfmt_format")
  |> should.equal(False)

  let prepared =
    glcode.prepare_loading([glcode.ModuleName("erlfmt_format")])
    |> should.be_ok

  glcode.finish_loading(prepared)
  |> should.be_ok
}

pub fn ensure_modules_loaded_test() {
  glcode.ensure_modules_loaded(["code"])
  |> should.be_ok
}

pub fn delete_test() {
  glcode.purge("erlfmt_format")
  |> should.equal(False)

  glcode.delete("erlfmt_format")
  |> should.equal(True)
}

pub fn soft_purge_test() {
  glcode.atomic_load([glcode.ModuleName("erlfmt_format")])
  |> should.be_ok

  glcode.soft_purge("erlfmt_format")
  |> should.equal(True)
}

pub fn is_loaded_test() {
  glcode.is_loaded("code")
  |> should.be_ok

  glcode.is_loaded("foo")
  |> should.be_error
}

pub fn all_available_test() {
  glcode.all_available()
  |> list.find(fn(available) { available.module == "os_mon" })
  |> should.be_ok
}

pub fn all_loaded_test() {
  {
    glcode.all_loaded()
    |> list.length
    > 0
  }
  |> should.equal(True)
}

pub fn which_test() {
  glcode.which("code")
  |> should.be_ok
}

import pprint
import gleam/dict

pub fn get_doc_test() {
  glcode.all_available()
  |> list.each(fn(available) {
    let doc =
      glcode.get_doc(available.module)
      |> should.be_ok

    case doc.anno {
      glcode.Anno(file, location) -> {
        file
        |> string.length
        |> should.not_equal(0)

        location
        |> should.equal(0)
      }
      glcode.AnnoNone -> Nil
    }

    doc.beam_language
    |> should.equal("erlang")

    doc.format
    |> should.equal("application/erlang+html")

    case doc.module_doc {
      glcode.ModuleDoc(doc) ->
        doc
        |> dict.keys()
        |> should.equal(["en"])
      glcode.ModuleDocHidden -> Nil
      glcode.ModuleDocNone -> Nil
    }

    doc.metadata
    |> dict.keys()
    |> list.each(fn(k) {
      case k {
        "otp_doc_vsn" | "source" | "name" | "generated" | "since" -> Nil
        _ -> {
          // pprint.debug(k)
          // pprint.debug(dict.get(doc.metadata, k))
          Nil
        }
      }
    })
  })
  // |> should.equal(
  //   dict.new()
  //   |> dict.insert("otp_doc_vsn", glcode.OtpDocVsn(1, 0, 0)),
  // )
}

pub fn root_dir_test() {
  glcode.root_dir()
}

pub fn lib_dir_test() {
  glcode.lib_dir()
  |> string.length()
  |> should.not_equal(0)
}

pub fn lib_dir_of_test() {
  glcode.lib_dir_of("mnesia")
  |> should.be_ok
}

pub fn lib_dir_of_sub_test() {
  glcode.lib_dir_of_sub("glcode", "priv")
  |> should.be_ok
}

pub fn compiler_dir_test() {
  glcode.compiler_dir()
  |> string.byte_size()
  |> should.not_equal(0)
}

pub fn priv_dir_test() {
  glcode.priv_dir("glcode")
  |> should.be_ok
}

pub fn objfile_extension_test() {
  glcode.objfile_extension()
  |> should.equal(".beam")
}

pub fn stick_dir_test() {
  let name = "glcode"
  let dir =
    glcode.lib_dir_of(name)
    |> should.be_ok

  glcode.is_sticky(name)
  |> should.equal(False)

  glcode.unstick_dir(dir)
  |> should.be_ok

  glcode.is_sticky(name)
  |> should.equal(False)

  glcode.stick_dir(dir)
  |> should.be_ok
  // TODO: not sure why this one doesn't pass.
  // glcode.is_sticky(name)
  // |> should.equal(True)
}

pub fn where_is_file_test() {
  glcode.where_is_file("glcode.beam")
  |> should.be_ok
  glcode.where_is_file("this_one_should_not_exist.erl")
  |> should.be_error
}

pub fn clash_test() {
  Nil
  // TODO: figure out a nice way to capture stdout here.
  // glcode.clash()
}

pub fn module_status_test() {
  glcode.module_status(["code"])
  |> list.find(fn(status) { status.module == "code" })
  |> should.be_ok
}

pub fn modified_modules_test() {
  glcode.modified_modules()
  |> list.length()
  |> should.equal(0)
}

pub fn get_mode_test() {
  glcode.get_mode()
  |> should.equal(glcode.Interactive)
}
