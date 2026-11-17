# Report export: APA-style tables, plots and interpretation as Word, PDF or HTML ----
# The results of the latest run of each analysis are turned into a flat list of
# blocks (heading, table, image, paragraph); one writer per format renders them.

sn_report_export <- function(sess, path, format = c("docx", "pdf", "html"), instances = NULL) {
  format <- match.arg(format)
  blocks <- sn_report_blocks(sess, instances)
  if (!length(blocks)) sn_abort("There are no results to export yet.", SN_ERR$invalid_params)
  switch(format, docx = sn_report_docx(blocks, path), pdf = sn_report_pdf(blocks, path),
         html = writeLines(sn_report_html(blocks), path, useBytes = TRUE))
  list(path = normalizePath(path, winslash = "/"), format = format)
}

sn_fmt_cell <- function(v, col) {
  if (is.null(v) || (length(v) == 1L && is.na(v))) return("")
  switch(col$type,
    text = as.character(v),
    int = as.character(round(as.numeric(v))),
    pvalue = fmt_p(as.numeric(v)),
    ci = if (length(v) != 2L || anyNA(v)) "" else fmt_ci(v[1], v[2], col$digits %||% 2L),
    fmt_num(as.numeric(v), col$digits %||% 2L))
}

sn_report_table <- function(t, number) {
  cells <- vapply(t$columns, function(col) {
    x <- t$rows[[col$id]]
    vapply(seq_len(nrow(t$rows)), function(i) sn_fmt_cell(if (is.list(x)) x[[i]] else x[i], col), "")
  }, character(nrow(t$rows)))
  list(type = "table", number = number, title = t$title, header = vapply(t$columns, function(c) c$label, ""),
       left = vapply(t$columns, function(c) c$type == "text", TRUE),
       cells = matrix(cells, nrow = nrow(t$rows)), notes = unlist(t$notes))
}

sn_report_blocks <- function(sess, instances = NULL) {
  an <- sess$analyses
  if (length(instances)) an <- an[intersect(instances, names(an))]
  blocks <- list(); n <- 0L; fig <- 0L
  add <- function(b) blocks[[length(blocks) + 1L]] <<- b
  for (a in an) {
    r <- a$result
    if (is.null(r)) next
    add(list(type = "heading", text = a$title))
    for (t in r$tables) add(sn_report_table(t, n <- n + 1L))
    for (p in r$plots) if (file.exists(p$svg)) add(list(type = "image", number = fig <- fig + 1L, title = p$title, svg = p$svg))
    if (!is.null(r$interpretation$text)) add(list(type = "para", text = r$interpretation$text))
    for (c in r$assumptions) if (!is.null(c$message)) add(list(type = "para", text = paste0(c$test, ": ", c$message), small = TRUE))
  }
  blocks
}

sn_xml <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

#' Height / width of a rendered SVG.
sn_svg_aspect <- function(svg) {
  d <- dim(rsvg::rsvg(svg, width = 120))
  d[1] / d[2]
}

#' Approximate width in points of serif text; needs an open graphics device.
sn_text_width <- function(s, pt) suppressWarnings(graphics::strwidth(s, units = "inches", family = "serif", cex = pt / 12)) * 72 * 1.06

# HTML -------------------------------------------------------------------------

sn_report_html <- function(blocks) {
  body <- vapply(blocks, function(b) switch(b$type,
    heading = paste0("<h2>", sn_xml(b$text), "</h2>"),
    para = paste0("<p", if (isTRUE(b$small)) " class=\"small\"", ">", sn_xml(b$text), "</p>"),
    image = paste0("<p class=\"num\">Figure ", b$number, "</p><p class=\"cap\">", sn_xml(b$title), "</p><img alt=\"", sn_xml(b$title),
                   "\" src=\"data:image/svg+xml;base64,", jsonlite::base64_enc(readBin(b$svg, "raw", file.size(b$svg))), "\">"),
    table = paste0(
      "<p class=\"num\">Table ", b$number, "</p><p class=\"cap\">", sn_xml(b$title), "</p><table><thead><tr>",
      paste0("<th", ifelse(b$left, " class=\"l\"", ""), ">", sn_xml(b$header), "</th>", collapse = ""), "</tr></thead><tbody>",
      paste0(apply(b$cells, 1, function(r) paste0("<tr>", paste0("<td", ifelse(b$left, " class=\"l\"", ""), ">", sn_xml(r), "</td>", collapse = ""), "</tr>")), collapse = ""),
      "</tbody></table>", if (length(b$notes)) paste0("<p class=\"note\"><i>Note.</i> ", sn_xml(paste(b$notes, collapse = " ")), "</p>"))
  ), "")
  paste(c("<!doctype html><html><head><meta charset=\"utf-8\"><title>StatNext results</title><style>",
    "body{font-family:'Times New Roman',Times,serif;font-size:12pt;max-width:7.5in;margin:1in auto;line-height:1.5;color:#000}",
    "h2{font-size:14pt;margin:28pt 0 8pt}.num{font-weight:bold;margin:14pt 0 0}.cap{font-style:italic;margin:0 0 4pt}",
    "table{border-collapse:collapse;border-top:1.5pt solid #000;border-bottom:1.5pt solid #000}",
    "th{border-bottom:1pt solid #000;font-weight:normal}th,td{padding:2pt 9pt;text-align:right;white-space:nowrap}.l{text-align:left}",
    ".note,.small{font-size:10.5pt;margin:3pt 0}img{width:6in;max-width:100%;display:block}",
    "</style></head><body>", body, "</body></html>"), collapse = "\n")
}

# Word (.docx) -----------------------------------------------------------------
# Written directly as WordprocessingML so tables stay editable and follow APA
# layout (rules above and below the header and at the bottom only).

sn_report_docx <- function(blocks, path) {
  if (!requireNamespace("zip", quietly = TRUE)) sn_abort("Package 'zip' is needed for Word export.", SN_ERR$missing_package, data = list(packages = list("zip")))
  dir <- tempfile("docx-"); for (d in c("word/media", "word/_rels", "_rels")) dir.create(file.path(dir, d), recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
  width <- function(s, pt) sn_text_width(s, pt)
  run <- function(text, bold = FALSE, italic = FALSE, size = NULL) paste0(
    "<w:r><w:rPr>", if (bold) "<w:b/>", if (italic) "<w:i/>", if (!is.null(size)) paste0("<w:sz w:val=\"", size, "\"/>"),
    "</w:rPr><w:t xml:space=\"preserve\">", sn_xml(text), "</w:t></w:r>")
  para <- function(runs, jc = NULL, before = 0, after = 0, keep = FALSE) paste0(
    "<w:p><w:pPr>", if (keep) "<w:keepNext/>", "<w:spacing w:before=\"", before, "\" w:after=\"", after, "\"/>",
    if (!is.null(jc)) paste0("<w:jc w:val=\"", jc, "\"/>"), "</w:pPr>", runs, "</w:p>")
  rule <- function(side, sz) paste0("<w:", side, " w:val=\"single\" w:sz=\"", sz, "\" w:space=\"0\" w:color=\"000000\"/>")
  images <- character()
  body <- vapply(blocks, function(b) switch(b$type,
    heading = para(run(b$text, bold = TRUE, size = 28), before = 360, after = 120, keep = TRUE),
    para = para(run(b$text, size = if (isTRUE(b$small)) 21), before = 80, after = 80),
    image = {
      id <- length(images) + 1L
      file <- paste0("plot", id, ".png")
      rsvg::rsvg_png(b$svg, file.path(dir, "word", "media", file), width = 1800)
      images[id] <<- file
      cx <- 5486400; cy <- round(cx * sn_svg_aspect(b$svg))
      paste0(
        para(run(paste("Figure", b$number), bold = TRUE), before = 240, keep = TRUE), para(run(b$title, italic = TRUE), after = 60, keep = TRUE),
        "<w:p><w:r><w:drawing><wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\"><wp:extent cx=\"", cx, "\" cy=\"", cy, "\"/>",
        "<wp:docPr id=\"", id, "\" name=\"Plot ", id, "\"/><a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">",
        "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"><pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">",
        "<pic:nvPicPr><pic:cNvPr id=\"", id, "\" name=\"", file, "\"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed=\"rImg", id, "\"/>",
        "<a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"", cx, "\" cy=\"", cy, "\"/></a:xfrm>",
        "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>")
    },
    table = {
      # Column widths in twips from the text; shrink the font when the table is wider than the page.
      pt <- 11; avail <- 9026; mar <- 100
      colw <- function(pt) vapply(seq_along(b$header), function(j) max(width(c(b$header[j], b$cells[, j]), pt)), 0) * 20 + 2 * mar + 40
      w <- colw(pt)
      if (sum(w) > avail) { pt <- max(6, floor(2 * pt * (avail - (2 * mar + 40) * length(w)) / (sum(w) - (2 * mar + 40) * length(w))) / 2); w <- colw(pt) }
      if (sum(w) > avail) w <- w * avail / sum(w)
      w <- round(w); sz <- round(pt * 2)
      cell <- function(text, left, width, header) paste0(
        "<w:tc><w:tcPr><w:tcW w:w=\"", width, "\" w:type=\"dxa\"/>", if (header) paste0("<w:tcBorders>", rule("bottom", 8), "</w:tcBorders>"), "</w:tcPr>",
        para(run(text, size = sz), jc = if (left) "left" else "right"), "</w:tc>")
      row <- function(x, header = FALSE) paste0("<w:tr>", if (header) "<w:trPr><w:tblHeader/></w:trPr>",
                                                paste0(mapply(cell, x, b$left, w, header), collapse = ""), "</w:tr>")
      paste0(
        para(run(paste("Table", b$number), bold = TRUE), before = 240, keep = TRUE), para(run(b$title, italic = TRUE), after = 60, keep = TRUE),
        "<w:tbl><w:tblPr><w:tblW w:w=\"", sum(w), "\" w:type=\"dxa\"/><w:tblBorders>", rule("top", 12), rule("bottom", 12), "</w:tblBorders>",
        "<w:tblLayout w:type=\"fixed\"/><w:tblCellMar><w:left w:w=\"", mar, "\" w:type=\"dxa\"/><w:right w:w=\"", mar, "\" w:type=\"dxa\"/></w:tblCellMar></w:tblPr>",
        "<w:tblGrid>", paste0("<w:gridCol w:w=\"", w, "\"/>", collapse = ""), "</w:tblGrid>",
        row(b$header, TRUE), paste0(apply(b$cells, 1, row), collapse = ""), "</w:tbl>",
        if (length(b$notes)) para(paste0(run("Note. ", italic = TRUE, size = 21), run(paste(b$notes, collapse = " "), size = 21)), before = 60) else para(""))
    }), "")
  ns <- paste0("xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" ",
               "xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"")
  head <- "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
  put <- function(file, ...) writeLines(enc2utf8(paste0(head, ...)), file.path(dir, file), useBytes = TRUE)
  put("word/document.xml", "<w:document ", ns, "><w:body>", paste(body, collapse = ""),
      "<w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/></w:sectPr></w:body></w:document>")
  put("word/styles.xml", "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:docDefaults><w:rPrDefault><w:rPr>",
      "<w:rFonts w:ascii=\"Times New Roman\" w:hAnsi=\"Times New Roman\" w:cs=\"Times New Roman\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr></w:rPrDefault>",
      "<w:pPrDefault><w:pPr><w:spacing w:after=\"0\" w:line=\"240\" w:lineRule=\"auto\"/></w:pPr></w:pPrDefault></w:docDefaults>",
      "<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/></w:style></w:styles>")
  put("word/_rels/document.xml.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
      "<Relationship Id=\"rStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
      paste0("<Relationship Id=\"rImg", seq_along(images), "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/", images, "\"/>", collapse = ""),
      "</Relationships>")
  put("_rels/.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
      "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>")
  put("[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">",
      "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/>",
      "<Default Extension=\"png\" ContentType=\"image/png\"/>",
      "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/></Types>")
  out <- file.path(normalizePath(dirname(path), winslash = "/"), basename(path))
  if (file.exists(out)) unlink(out)
  zip::zip(out, files = c("[Content_Types].xml", "_rels", "word"), root = dir, mode = "mirror")
  invisible(out)
}

# PDF --------------------------------------------------------------------------
# Pages are laid out as SVG (full Unicode, so χ², η² and β print correctly),
# converted with rsvg and joined with qpdf.

sn_report_pdf <- function(blocks, path) {
  need <- c("rsvg", "qpdf")
  need <- need[!vapply(need, requireNamespace, TRUE, quietly = TRUE)]
  if (length(need)) sn_abort(paste0("PDF export needs the R package(s): ", paste(need, collapse = ", ")), SN_ERR$missing_package, data = list(packages = as.list(need)))
  W <- 595; H <- 842; M <- 62; avail <- W - 2 * M
  grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
  width <- function(s, pt) sn_text_width(s, pt)
  pages <- list(); cur <- character(); y <- M
  flush <- function() { if (length(cur)) pages[[length(pages) + 1L]] <<- cur; cur <<- character(); y <<- M }
  room <- function(h) if (y + h > H - M) flush()
  text <- function(s, x, yy, pt, anchor = "start", style = "") cur[length(cur) + 1L] <<- paste0(
    "<text x=\"", round(x, 2), "\" y=\"", round(yy, 2), "\" font-size=\"", round(pt, 2), "\" text-anchor=\"", anchor, "\" ", style, ">", sn_xml(s), "</text>")
  line <- function(x1, x2, yy, sw) cur[length(cur) + 1L] <<- paste0(
    "<line x1=\"", round(x1, 2), "\" x2=\"", round(x2, 2), "\" y1=\"", round(yy, 2), "\" y2=\"", round(yy, 2), "\" stroke=\"#000\" stroke-width=\"", sw, "\"/>")
  wrap <- function(s, pt, maxw) {
    words <- strsplit(s, " +")[[1]]; out <- character(); ln <- ""
    for (w in words) {
      try <- if (nzchar(ln)) paste(ln, w) else w
      if (width(try, pt) > maxw && nzchar(ln)) { out <- c(out, ln); ln <- w } else ln <- try
    }
    c(out, ln)
  }
  para <- function(s, pt, style = "", gap = 6) {
    for (ln in wrap(s, pt, avail)) { room(pt * 1.4); y <<- y + pt * 1.4; text(ln, M, y - pt * 0.3, pt, style = style) }
    y <<- y + gap
  }
  for (b in blocks) switch(b$type,
    heading = { room(60); y <- y + 14; para(b$text, 14, "font-weight=\"bold\"", 8) },
    para = para(b$text, if (isTRUE(b$small)) 9.5 else 11),
    image = {
      w <- avail * 0.85; h <- w * sn_svg_aspect(b$svg)
      room(h + 40)
      para(paste("Figure", b$number), 11, "font-weight=\"bold\"", 0); para(b$title, 11, "font-style=\"italic\"", 4)
      png <- tempfile(fileext = ".png"); rsvg::rsvg_png(b$svg, png, width = 1600)
      cur[length(cur) + 1L] <- paste0("<image x=\"", M, "\" y=\"", round(y, 2), "\" width=\"", round(w, 2), "\" height=\"", round(h, 2),
                                      "\" xlink:href=\"data:image/png;base64,", jsonlite::base64_enc(readBin(png, "raw", file.size(png))), "\"/>")
      unlink(png); y <- y + h + 14
    },
    table = {
      pt <- 10; pad <- 7
      colw <- function(pt) vapply(seq_along(b$header), function(j) max(width(c(b$header[j], b$cells[, j]), pt)), 0) + 2 * pad
      w <- colw(pt)
      if (sum(w) > avail) { pt <- max(5.5, pt * (avail - 2 * pad * length(w)) / (sum(w) - 2 * pad * length(w))); pad <- pad * pt / 10; w <- colw(pt) }
      if (sum(w) > avail) w <- w * avail / sum(w)
      x0 <- M + c(0, cumsum(w)[-length(w)]); rh <- pt * 1.65; tw <- sum(w)
      row <- function(x, yy) for (j in seq_along(x))
        if (b$left[j]) text(x[j], x0[j] + pad, yy, pt) else text(x[j], x0[j] + w[j] - pad, yy, pt, "end")
      header <- function() { line(M, M + tw, y, 1.2); row(b$header, y + rh * 0.68); y <<- y + rh; line(M, M + tw, y, 0.7) }
      room(rh * (min(nrow(b$cells), 3) + 2) + 40)
      para(paste("Table", b$number), 11, "font-weight=\"bold\"", 0); para(b$title, 11, "font-style=\"italic\"", 4)
      header()
      for (i in seq_len(nrow(b$cells))) {
        if (y + rh > H - M) { line(M, M + tw, y, 1.2); flush(); header() }
        row(b$cells[i, ], y + rh * 0.68); y <- y + rh
      }
      line(M, M + tw, y, 1.2); y <- y + 5
      if (length(b$notes)) para(paste("Note.", paste(b$notes, collapse = " ")), 9.5, "font-style=\"italic\"", gap = 2)
      y <- y + 10
    })
  flush()
  files <- vapply(seq_along(pages), function(i) {
    svg <- paste0("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"", W, "pt\" height=\"", H, "pt\" viewBox=\"0 0 ", W, " ", H,
                  "\" font-family=\"Times New Roman, Times, Liberation Serif, serif\"><rect width=\"", W, "\" height=\"", H, "\" fill=\"#fff\"/>",
                  paste(pages[[i]], collapse = ""),
                  "<text x=\"", W / 2, "\" y=\"", H - 30, "\" font-size=\"9\" text-anchor=\"middle\">", i, "</text></svg>")
    f <- tempfile(fileext = ".pdf"); rsvg::rsvg_pdf(charToRaw(enc2utf8(svg)), f); f
  }, "")
  on.exit(unlink(files), add = TRUE)
  if (file.exists(path)) unlink(path)
  if (length(files) == 1L) file.copy(files, path) else qpdf::pdf_combine(files, path)
  invisible(path)
}
