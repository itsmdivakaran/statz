# Plugins ----------------------------------------------------------------------------
# A plugin is an analysis module (spec.json + R file + optional help.md) installed into
# the user's plugin folder. It uses the same format and runner as the built-in modules.
# Plugins run R code on the user's computer, so the UI asks before installing one.

SN_PLUGIN_ID <- "^[a-z][a-z0-9_]{1,40}$"

sn_plugin_dir <- function(sess) {
  d <- sess$plugin_dir
  if (is.null(d)) sn_abort("Plugins are not available in this session.", SN_ERR$not_found)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

#' Validate a module folder. Returns list(ok, errors, spec).
sn_plugin_check <- function(dir) {
  errors <- character()
  spec_file <- file.path(dir, "spec.json")
  if (!file.exists(spec_file)) return(list(ok = FALSE, errors = "No spec.json in the folder.", spec = NULL))
  spec <- tryCatch(jsonlite::fromJSON(spec_file, simplifyVector = FALSE),
                   error = function(e) { errors <<- c(errors, paste("spec.json is not valid JSON:", conditionMessage(e))); NULL })
  if (is.null(spec)) return(list(ok = FALSE, errors = errors, spec = NULL))
  need <- c("id", "version", "title", "menu", "r", "roles", "options")
  miss <- setdiff(need, names(spec))
  if (length(miss)) errors <- c(errors, paste0("spec.json is missing: ", paste(miss, collapse = ", "), "."))
  if (!is.null(spec$id) && !grepl(SN_PLUGIN_ID, spec$id))
    errors <- c(errors, "id must be lower case letters, digits and underscores, starting with a letter.")
  if (!is.null(spec$menu) && !length(spec$menu)) errors <- c(errors, "menu needs at least one entry.")
  if (is.null(spec$r$file) || is.null(spec$r$fn)) errors <- c(errors, "r.file and r.fn are required.")
  else if (!file.exists(file.path(dir, spec$r$file))) errors <- c(errors, paste0("R file not found: ", spec$r$file, "."))
  for (role in spec$roles %||% list()) if (is.null(role$id) || is.null(role$label))
    errors <- c(errors, "Every role needs an id and a label.")
  for (nm in names(spec$options %||% list())) {
    t <- spec$options[[nm]]$type
    if (!isTRUE(t %in% c("enum", "number", "bool", "text", "subset", "interactions")))
      errors <- c(errors, paste0("Option '", nm, "' has an unknown type."))
  }
  if (!length(errors)) {
    mod <- tryCatch(sn_load_module(dir), error = function(e) { errors <<- c(errors, paste("R file:", conditionMessage(e))); NULL })
  }
  list(ok = !length(errors), errors = as.list(errors), spec = spec)
}

#' Plugin summaries for the plugin manager.
sn_plugin_list <- function(sess) {
  mods <- Filter(function(m) identical(m$source, "plugin"), sess$modules)
  lapply(unname(mods), function(m) {
    pk <- unlist(m$spec$r$packages)
    list(id = m$spec$id, title = m$spec$title, version = m$spec$version %||% "", author = m$spec$author %||% "",
         description = m$spec$description %||% "", menu = m$spec$menu, dir = normalizePath(m$dir, winslash = "/"),
         missing_packages = as.list(pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]))
  })
}

#' Find the module folder in an unpacked plugin: the folder itself or its only sub-folder with a spec.json.
sn_plugin_root <- function(dir) {
  if (file.exists(file.path(dir, "spec.json"))) return(dir)
  subs <- list.dirs(dir, recursive = FALSE)
  subs <- subs[file.exists(file.path(subs, "spec.json"))]
  if (length(subs) == 1L) return(subs)
  sn_abort("Could not find a plugin (a folder with spec.json) here.", SN_ERR$invalid_options)
}

#' The module folder of a plugin given as a folder or a .zip file (unpacked to a temp folder).
sn_plugin_unpack <- function(path) {
  if (is.null(path) || !file.exists(path)) sn_abort("File or folder not found.", SN_ERR$not_found)
  src <- path
  if (!dir.exists(path)) {
    if (!grepl("\\.zip$", path, ignore.case = TRUE)) sn_abort("Choose a plugin folder or a .zip file.", SN_ERR$invalid_options)
    src <- tempfile("plugin-")
    utils::unzip(path, exdir = src)
  }
  sn_plugin_root(src)
}

#' Install (or update) a plugin from a folder or a .zip file.
sn_plugin_install <- function(sess, path) {
  src <- sn_plugin_unpack(path)
  chk <- sn_plugin_check(src)
  if (!chk$ok) sn_abort(paste("This plugin cannot be installed:", paste(unlist(chk$errors), collapse = " ")),
                        SN_ERR$invalid_options, data = list(errors = chk$errors))
  id <- chk$spec$id
  existing <- sess$modules[[id]]
  if (!is.null(existing) && !identical(existing$source, "plugin"))
    sn_abort(paste0("'", id, "' is the id of a built-in analysis; give the plugin another id."), SN_ERR$invalid_options)
  dest <- file.path(sn_plugin_dir(sess), id)
  if (dir.exists(dest)) unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE)
  files <- list.files(src, recursive = TRUE, all.files = FALSE)
  for (f in files) {
    dir.create(dirname(file.path(dest, f)), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(src, f), file.path(dest, f), overwrite = TRUE)
  }
  mod <- sn_load_module(dest)
  mod$source <- "plugin"
  mod$spec$source <- "plugin"
  sess$modules[[id]] <- mod
  info <- Filter(function(p) p$id == id, sn_plugin_list(sess))[[1]]
  c(info, list(updated = !is.null(existing)))
}

sn_plugin_remove <- function(sess, id) {
  m <- sess$modules[[id]]
  if (is.null(m) || !identical(m$source, "plugin")) sn_abort(paste0("No plugin with id '", id, "'."), SN_ERR$not_found)
  unlink(m$dir, recursive = TRUE)
  sess$modules[[id]] <- NULL
  list(ok = TRUE)
}

#' Re-read every plugin from disk (after editing a plugin's files).
sn_plugin_reload <- function(sess) {
  for (id in names(sess$modules)) if (identical(sess$modules[[id]]$source, "plugin")) sess$modules[[id]] <- NULL
  sn_load_modules(sess, sess$plugin_dir, source = "plugin")
  sn_plugin_list(sess)
}

#' Write a working starter plugin to `path`/<id> for authors to copy and edit.
sn_plugin_template <- function(path, id = "coef_variation") {
  if (!grepl(SN_PLUGIN_ID, id)) sn_abort("Invalid plugin id.", SN_ERR$invalid_options)
  dest <- file.path(path, id)
  if (file.exists(dest)) sn_abort(paste0("A folder named '", id, "' already exists there."), SN_ERR$invalid_options)
  dir.create(dest, recursive = TRUE)
  tpl <- system.file("plugin-template", package = "statnextr")
  if (!nzchar(tpl)) tpl <- file.path(getwd(), "inst", "plugin-template")
  for (f in list.files(tpl)) {
    txt <- readLines(file.path(tpl, f), warn = FALSE, encoding = "UTF-8")
    out <- sub("coef_variation", id, f, fixed = TRUE)
    writeLines(gsub("coef_variation", id, txt, fixed = TRUE), file.path(dest, out), useBytes = TRUE)
  }
  list(path = normalizePath(dest, winslash = "/"))
}
