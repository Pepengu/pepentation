#import "utils.typ"

/// Estimates the footer height to adjust page margins.
///
/// Calculates the required footer height based on the footer configuration,
/// taking into account the number of authors and available width. This ensures
/// that the page bottom margin is properly adjusted to accommodate the footer.
///
/// # Parameters
/// - `footer` (dictionary): Footer configuration dictionary.
/// - `theme` (dictionary): Theme configuration (unused but kept for consistency).
/// - `page-height` (length): The height of the page.
///
/// # Returns
/// The estimated footer height in points. Returns `0pt` if footer is disabled.
#let estimate-footer-height(footer, theme, page-height) = {
  if not footer.enable { return 0pt }

  let page-width = page-height * 16 / 10
  let available-width = (page-width / 3) - 2.5cm
  // Temporarily ignore authors for estimation
  let char-count = footer.authors.join(", ", default: "").len()

  let lines = if char-count > 0 {
    calc.ceil(char-count / (available-width / 5.5pt))
  } else {
    1
  }

  calc.max(lines * 0.7em, 1em)
}

/// Renders the presentation footer with a 3-column layout.
///
/// The footer displays:
/// - Left column: Authors and institute name
/// - Center column: Short presentation title
/// - Right column: Date and page number
///
/// # Parameters
/// - `footer` (dictionary): Footer configuration with `enable`, `title`, `authors`, `institute`, and `date`.
/// - `theme` (dictionary): Theme configuration containing color settings.
/// - `page-width` (length): The width of the page.
/// - `fixed-height` (length): The fixed height allocated for the footer.
///
/// # Returns
/// A content block containing the rendered footer, or empty content if footer is disabled.
#let create-footer(footer, theme, page-width, fixed-height) = {
  set text(size: 12pt, weight: "regular", top-edge: "cap-height", bottom-edge: "baseline")

  if not footer.enable { return }

  let sub-text = theme.sub-text

  let c-authors = if footer.authors != none and footer.authors.len() > 0 {
    text(fill: sub-text)[
      #grid(
        columns: 2, align: (left+horizon, center+horizon),
        box(width: 100%, align(horizon)[
          #set par(leading: 0.2em, justify: false)
          #footer.authors.join(", ")
        ]),
        box(width: 5em, footer.institute)
      )
    ]
  } else {
    align(center+horizon, text(fill: sub-text, footer.institute))
  }

  let c-title = align(horizon+center, text(fill: sub-text)[
    #v(-0.1em) #footer.title
  ])

  let c-date = grid(
    columns: 2, align: (left+horizon, right+horizon),
    box(width: 100%, text(fill: sub-text)[~#footer.date]),
    box(width: 10%, align(horizon, text(fill: sub-text)[
      #v(-0.1em)
      #context counter(page).display("1/1", both: true)
    ]))
  )

  grid(
    columns: (1fr, 1fr, 1fr),
    inset: -1pt, 
    align: bottom,
    box(
      fill: theme.primary, width: 100%, height: fixed-height,
      outset: (bottom: 3em, left: 0.5cm, top: 0.5em),
      align(horizon, move(dy: -0.3em, c-authors))
    ),
    box(
      fill: theme.secondary, width: 100%, height: fixed-height,
      outset: (bottom: 3em, top: 0.5em),
      align(horizon+center, move(dy: -0.2em, c-title))
    ),
    box(
      fill: theme.primary, width: 100%, height: fixed-height,
      outset: (bottom: 3em, top: 0.5em, right: 1cm),
      align(horizon, move(dy: -0.2em, c-date))
    ),
  )
}

/// Font size of the header titles in their unscaled form.
#let header-title-size = 14pt

/// Lower bound for automatic title shrinking in the header.
#let header-min-title-size = 9pt

/// Maximum number of lines a header title may occupy.
#let header-max-title-lines = 2

/// Maximum number of rows the slide tracker may occupy.
#let header-max-tracker-rows = 3

/// Largest share of slides that may be hidden behind a trailing ellipsis.
#let header-hide-limit = 0.25

/// Gap between two neighbouring header columns.
#let header-cell-gutter = 0.3cm

/// Builds text with the properties the header is rendered with.
///
/// The properties have to be spelled out on every call: `set text` inside a
/// `context` block does not apply to `measure` calls made in the same block,
/// and the header is built inside a heading show rule, whose ambient text is
/// bold and larger than the header itself. Measuring against that ambient
/// makes every title look too wide, so the tracker wraps early and the titles
/// shrink further than necessary.
///
/// The text is also set ragged right and without hyphenation, because a header
/// title is a label in a narrow column: justifying it would stretch the gaps and
/// hyphenating it would break the words.
///
/// # Parameters
/// - `size` (length): Font size of the text.
/// - `fill` (color): Fill of the text.
/// - `body` (str or content): The text itself.
///
/// # Returns
/// A content block with the requested text.
#let header-text(size: header-title-size, fill: black, body) = {
  // The header is a list of short labels in narrow columns, so the text is set
  // ragged right and never hyphenated: justification would stretch the gaps and
  // hyphenation would break the words. Measurement runs through here too, which
  // is what keeps `title-height` in step with what is rendered.
  set par(justify: false)
  text(size: size, weight: "regular", fill: fill, hyphenate: false, body)
}

/// Measures the width of every glyph used by the header at a given size.
///
/// The glyphs are passed to `text` as strings on purpose: the same characters
/// written as markup literals measure up to three times too wide, which would
/// make the tracker wrap long before it runs out of room.
///
/// # Parameters
/// - `size` (length): Font size to measure at.
///
/// # Returns
/// A dictionary mapping every tracker glyph to its advance width.
#let glyph-widths(size) = (
  "•": measure(header-text(size: size, "•")).width,
  "●": measure(header-text(size: size, "●")).width,
  "◦": measure(header-text(size: size, "◦")).width,
  "…": measure(header-text(size: size, "…")).width,
)

/// Greedily packs tracker glyphs into rows of at most `available-width`.
///
/// Every glyph is measured individually, because the three tracker glyphs do
/// not necessarily share the same advance width. `reserve` is left free at the
/// end of every row, which guarantees that a trailing `…` fits on the last row.
///
/// # Parameters
/// - `dots` (array): Glyph strings to pack.
/// - `widths` (dictionary): Glyph widths as returned by `glyph-widths`.
/// - `available-width` (length): Width of a single row.
/// - `reserve` (length): Width to keep free at the end of every row.
///
/// # Returns
/// An array of rows, each row being an array of glyphs.
#let pack-rows(dots, widths, available-width, reserve) = {
  let rows = ()
  let row = ()
  let used = reserve
  for dot in dots {
    let width = widths.at(dot, default: available-width)
    if row.len() > 0 and used + width > available-width {
      rows.push(row)
      row = ()
      used = reserve
    }
    row.push(dot)
    used += width
  }
  if row.len() > 0 { rows.push(row) }
  rows
}

/// Builds the slide tracker of a single header cell.
///
/// Normally there is exactly one glyph per slide, but the height of the header
/// must not grow with the length of a talk. At most `max-rows` rows are drawn:
/// - If everything fits, one glyph per slide is used.
/// - If at most `hide-limit` of the slides do not fit, the rows are filled and
///   a dimmed `…` marks the omitted slides.
/// - Otherwise the slides are grouped into runs of `ceil(n / max-rows)` slides
///   and one glyph is drawn per run: `•` for a run in the past, `●` for the run
///   containing the current slide, `◦` for a run in the future.
///
/// `dots` has to be in presentation order and holds at most one `●`, that is
/// `•* ●? ◦*`. Both compaction steps rely on it: the space reserved for the `…`
/// only covers replacing a `•` with the wider `●`, and a run is in the past
/// exactly when it starts with a `•`.
///
/// # Parameters
/// - `dots` (array): Glyph strings, in presentation order.
/// - `widths` (dictionary): Glyph widths as returned by `glyph-widths`.
/// - `available-width` (length): Width of a single row.
/// - `max-rows` (integer): Maximum number of rows.
/// - `hide-limit` (float): Maximum share of slides hidden behind `…`.
///
/// # Returns
/// An array of rows, each row being an array of glyphs.
#let render-tracker(dots, widths, available-width, max-rows, hide-limit) = {
  if dots.len() == 0 { return () }

  let rows = pack-rows(dots, widths, available-width, 0pt)
  if rows.len() <= max-rows { return rows }

  // Fill `max-rows` rows, leaving room on the last one for a trailing ellipsis
  // and for the slightly wider marker of the current slide.
  let ellipsis = widths.at("…")
  let marker = widths.at("●") - widths.at("•")
  let keep = 0
  for row in rows.slice(0, max-rows) { keep += row.len() }
  let filled = ()
  while keep > 0 {
    let candidate = pack-rows(dots.slice(0, keep), widths, available-width, 0pt)
    if candidate.len() > max-rows { break }
    let used = 0pt
    for dot in candidate.last() { used += widths.at(dot) }
    if used + ellipsis + marker <= available-width {
      filled = candidate
      break
    }
    keep -= 1
  }

  let shown = 0
  for row in filled { shown += row.len() }
  let hidden = dots.len() - shown
  if shown > 0 and hidden <= dots.len() * hide-limit {
    if not filled.flatten().contains("●") {
      // The current slide did not fit into the shown part, so the last shown
      // dot takes its place instead of hiding the position altogether.
      let last = filled.last()
      let patched = last.slice(0, last.len() - 1)
      patched.push("●")
      filled = filled.slice(0, filled.len() - 1) + (patched,)
    }
    filled.last().push("…")
    return filled
  }

  // One glyph per run of slides, so that the tracker never needs more rows
  // than allowed, no matter how long the talk is.
  let bucket = calc.max(1, calc.ceil(dots.len() / max-rows))
  let glyphs = ()
  let i = 0
  while i < dots.len() {
    let run = dots.slice(i, calc.min(i + bucket, dots.len()))
    glyphs.push(if run.contains("●") {
      "●"
    } else if run.first() == "•" {
      "•"
    } else {
      "◦"
    })
    i += bucket
  }
  pack-rows(glyphs, widths, available-width, 0pt)
}

/// Returns the height of a block of `lines` lines of text at a given size.
#let line-budget(size, lines) = {
  let body = [x]
  for _ in range(1, lines) { body += [#linebreak()y] }
  measure(box(width: 10000cm, header-text(size: size, body))).height
}

/// Returns the height of a title once it is wrapped into `max-width`.
#let title-height(title, size, max-width) = {
  measure(box(width: max-width, header-text(size: size)[#title])).height
}

/// Returns the width of a title if it is not wrapped at all.
#let title-width(title, size) = measure(header-text(size: size)[#title]).width

/// Checks whether a title fits into `max-lines` lines of `max-width`.
///
/// Both the width and the height have to be checked: a title that cannot be
/// broken (a single long word) keeps the height of a single line while it
/// overflows horizontally, and a title that wraps badly can need more lines
/// than its width suggests.
///
/// # Parameters
/// - `title` (str): The title to check.
/// - `size` (length): Font size of the title.
/// - `max-width` (length): Width of a single line.
/// - `max-lines` (integer): Maximum number of lines.
/// - `budget` (length or none, default: `none`): The height that `max-lines`
///   lines of text occupy, if it has already been measured for `size`.
///
/// # Returns
/// `true` if the title fits.
#let title-fits(title, size, max-width, max-lines, budget: none) = {
  if title.len() == 0 { return true }
  if title-width(title, size) > max-width * max-lines { return false }
  let budget = if budget == none { line-budget(size, max-lines) } else { budget }
  title-height(title, size, max-width) <= budget
}

/// Returns the largest size at which every title fits into `max-lines` lines.
///
/// # Parameters
/// - `titles` (array): Titles to fit.
/// - `widths` (array): Available width per title.
/// - `max-lines` (integer): Maximum number of lines per title.
/// - `max-size` (length): Largest size to try.
/// - `min-size` (length): Smallest size to try.
///
/// # Returns
/// The fitted size, or `none` if even `min-size` is too large.
#let fit-size(titles, widths, max-lines, max-size, min-size) = {
  let size = max-size
  while size >= min-size {
    // The line budget only depends on the size, so it is measured once per
    // step instead of once per title.
    let budget = line-budget(size, max-lines)
    let fits = true
    for (i, title) in titles.enumerate() {
      if not title-fits(title, size, widths.at(i), max-lines, budget: budget) {
        fits = false
        break
      }
    }
    if fits { return size }
    size -= 0.5pt
  }
  none
}

/// Truncates a title to the longest prefix that still fits, adding `…`.
#let truncate-title(title, size, max-width, max-lines) = {
  let clusters = title.clusters()
  let low = 0
  let high = clusters.len()
  while low < high {
    let mid = calc.ceil((low + high) / 2)
    let candidate = clusters.slice(0, mid).join("", default: "") + "…"
    if title-fits(candidate, size, max-width, max-lines) {
      low = mid
    } else {
      high = mid - 1
    }
  }
  clusters.slice(0, low).join("", default: "") + "…"
}

/// Renders the navigation header with section titles and progress tracker.
///
/// The header displays:
/// - Section titles (from level 1 headings), scaled down uniformly so that all
///   of them fit into the same number of lines, and truncated with `…` if even
///   the smallest size is not enough. Every title and tracker is aligned to the
///   left of its own column, and neighbouring columns are separated by a
///   gutter, so the header reads as one list from the left margin onwards.
/// - Progress indicators showing one glyph per slide:
///   - `•` for completed slides
///   - `●` for the current slide
///   - `◦` for upcoming slides
///   The tracker is measured instead of guessed, and its height is capped, so
///   that it never pushes the slide content down, no matter how long the talk
///   is (see `render-tracker`).
///
/// # Parameters
/// - `theme` (dictionary): Theme configuration containing color settings.
/// - `width` (length): Width available to the header, excluding page margins.
///
/// # Returns
/// A content block containing the rendered header with navigation.
#let create-header(theme, width) = {
  context {
    set text(size: header-title-size, weight: "regular")

    let all-slides = query(selector(heading))
    if all-slides.len() == 0 { return }

    let current-slide-idx = {
      let n = query(selector(heading).before(here())).len()
      if n > 0 { n - 1 } else { 0 }
    }

    let dim-color = theme.sub-text.rgb().transparentize(50%)
    let active-color = theme.sub-text

    let section-title = ""
    let dots = ()
    let is-current-section = false
    let sections = ()

    for (i, slide) in all-slides.enumerate() {
      if slide.level == 1 {
        // A section only exists once it has a title or at least one slide, so
        // that a deck starting with a section does not get an empty cell.
        if section-title != "" or dots.len() > 0 {
          sections.push((
            title: section-title,
            dots: dots,
            current: is-current-section,
          ))
        }
        section-title = utils.heading-title(slide.body)
        dots = ()
        // A section is the current one as soon as it has started: the header is
        // only drawn on slides, so the index of the current slide can never be
        // the index of a section heading itself.
        is-current-section = i <= current-slide-idx
        continue
      }

      dots.push(if i < current-slide-idx { "•" } else if i == current-slide-idx { "●" } else { "◦" })
    }
    if section-title != "" or dots.len() > 0 {
      sections.push((
        title: section-title,
        dots: dots,
        current: is-current-section,
      ))
    }
    if sections.len() == 0 { return }

    let num-sections = sections.len()
    let widths = glyph-widths(header-title-size)
    // The columns share the width evenly, and a gutter keeps neighbouring
    // sections apart instead of letting their titles touch.
    let cell-width = calc.max(
      width - header-cell-gutter * (num-sections - 1),
      num-sections * 1pt,
    ) / num-sections

    let titles = sections.map(s => s.title)
    let title-lines = 1
    let title-size = fit-size(
      titles, range(num-sections).map(_ => cell-width), title-lines,
      header-title-size, header-min-title-size,
    )
    if title-size == none {
      title-lines = header-max-title-lines
      title-size = fit-size(
        titles, range(num-sections).map(_ => cell-width), title-lines,
        header-title-size, header-min-title-size,
      )
    }
    if title-size == none { title-size = header-min-title-size }
    let title-box-height = line-budget(title-size, title-lines)

    let headers = ()
    for section in sections {
      let color = if section.current { active-color } else { dim-color }

      let title = section.title
      if not title-fits(title, title-size, cell-width, title-lines) {
        title = truncate-title(title, title-size, cell-width, title-lines)
      }

      let rows = render-tracker(
        section.dots, widths, cell-width,
        header-max-tracker-rows, header-hide-limit,
      )

      // A section without a title gets no title box at all, instead of a blank
      // line above its dots. Cells with a title keep the shared box height, so
      // their trackers stay aligned with the ones next to them.
      let title-box = if section.title == "" {
        ()
      } else {
        (
          box(
            width: 100%,
            height: title-box-height,
            // Top, not the default middle: a one-line title would otherwise
            // float inside the fixed-height box and lift its tracker away from
            // the trackers of the neighbouring cells.
            align(left + top, header-text(size: title-size, fill: color)[#title]),
          ),
          v(0.2em),
        )
      }

      headers.push(box(
        width: 100%,
        outset: (top: 0.1cm, bottom: 0.1cm),
      )[
        #grid(
          columns: 1,
          v(0.1em),
          ..title-box,
          ..rows.map(row => align(left, header-text(fill: color)[#row.join()])),
        )
      ])
    }

    grid(
      // The exact `cell-width` the titles were fitted and the rows were packed
      // for, not `1fr`: proportional tracks only ever approximate that division,
      // and the layout is only as good as the agreement between what is measured
      // and what is rendered.
      columns: range(num-sections).map(_ => cell-width),
      gutter: header-cell-gutter,
      ..headers,
    )
  }
}
