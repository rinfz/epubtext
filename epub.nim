import std/[encodings, strutils, streams, xmltree, xmlparser, tables, htmlparser, sequtils]
import zip/zipfiles

proc opfFile(container: var ZipArchive): string =
  for file in container.walkFiles:
    if file.endsWith(".opf"):
      return container.getStream(file).readAll()
  return "error::missing opf"

proc fileOrder(opfData: string): seq[string] =
  let content = opfData.parseXml()
  var pageMap = initTable[string, string]()
  for item in content.findAll("item"):
    let
      href = item.attr("href")
      id = item.attr("id")
    if href.len > 0 and id.len > 0: pageMap[id] = href
  for itemref in content.findAll("itemref"):
    let idref = itemref.attr("idref")
    if idref.len > 0: result.add pageMap[idref]

proc pageText(container: var ZipArchive; page: string): string =
  let content = container.getStream(page).readAll()
  var html: XMLNode
  try:
    html = parseHtml(content)
  except:
    try:
      html = parseXml(content)
    except:
      return "error::unable to read page"
  return html.findAll("body")[0].innerText

proc pages(container: var ZipArchive): seq[string] =
  return container.opfFile.fileOrder

proc numPages(filename: cstring): int {.exportc,dynlib.} =
  var container: ZipArchive
  if not container.open($filename):
    return -1
  return container.opfFile.fileOrder.len

proc postprocess(content: string): cstring =
  content.convert("latin1", "UTF-8").cstring

proc extractText*(filename: cstring): cstring {.exportc,dynlib.} =
  var container: ZipArchive
  if not container.open($filename):
    return "error::unable to open epub"

  var buf = ""
  for page in container.pages:
    buf.add container.pageText(page)
    buf.add "\n"

  return buf.postprocess

proc extractPageText*(filename: cstring; n: cint): cstring {.exportc,dynlib.} =
  var container: ZipArchive
  if not container.open($filename):
    return "error::unable to open epub"
  let pages = container.pages.toSeq
  if n >= 1 and n <= pages.len:
    return container.pageText(pages[n-1]).postprocess
  else:
    return "error::page out of range"
