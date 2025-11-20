//Header
//Header
#let create_header(theme) = {
  context {
set text(size: 14pt)

    let current_slide = {
      let n = query(selector(heading).before(here())).len()
      if n > 0 { n - 1 } else { 0 }
    }
    let slides = query(selector(heading))

    let section = ""
    let circles = ()  
    let headers = ()

    let dim_color = theme.sub-text.rgb().transparentize(50%)
    let text_color = dim_color

    let split_circles = (section, circles, color) => {
      if circles.len() == 0 {
        return (text(fill: color)[],)
      }

      let title_width = measure(text(fill: color)[#section]).width
      if title_width == 0pt {
        return (text(fill: color)[#circles.join("")],)
      }

      let max_fit = 1
      for n in range(1, circles.len() + 1) {
        let s = circles.slice(0, n).join("")
        let w = measure(text(fill: color)[#s]).width
        if w <= title_width {
          max_fit = n
        } else {
          break
        }
      }

      let max_per_line = max_fit
      if max_per_line < 6 {
        max_per_line = 6
      }

      if circles.len() <= max_per_line {
        return (text(fill: color)[#circles.join("")],)
      }

      let lines = ()
      let i = 0
      while i < circles.len() {
        let j = i + max_per_line
        if j > circles.len() {
          j = circles.len()
        }
        let chunk = circles.slice(i, j)
        lines.push(text(fill: color)[#chunk.join("")])
        i = j
      }
      lines
    }

    let make_cell = (section, circles, alignment, outset, color) => {
      let circle_lines = split_circles(section, circles, color)
      [
        #box(
          width: 100%,
          outset: outset,
        )[
          #align(
            alignment,
            grid(
              columns: 1,
              align: (left, left),
              v(0.1em),
              text(fill: color)[#section],
              v(0.2em),
              ..circle_lines,
            ),
          )
        ]
      ]
    }

    for i in range(0, slides.len()) {
      let slide = slides.at(i)

      if slide.level == 1 {
        let outset = (left: 0.1cm, bottom: 0.1cm, top: 0.1cm)
        let alignment = center

        if headers.len() == 1 {
          alignment = left
          outset = (left: 0.5cm, bottom: 0.1cm, top: 0.1cm)
        }

        headers.push(make_cell(section, circles, alignment, outset, text_color))

        section = slide.body
        circles = ()
        text_color = dim_color
        continue
      }

      if i < current_slide {
        circles.push("•")
      } else if i == current_slide {
        circles.push("●")
        text_color = theme.sub-text
      } else {
        circles.push("◦")
      }    
    }

    headers.push(
      make_cell(
        section,
        circles,
        right,
        (right: 0.5cm, bottom: 0.1cm, top: 0.1cm),
        text_color,
      )
    )

    grid(
      columns: headers.len(),
      ..headers.slice(1),
    )
  }
}

//Display current day
#let today(locale) = {
  assert(locale in ("RU", "EN"))

  let date_en = ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
  let date_ru = ("Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь")

  (
    (locale == "EN", [#date_en.at(datetime.today().month() - 1) #datetime.today().year()]),
    (locale == "RU", [#date_ru.at(datetime.today().month() - 1) #datetime.today().year()])
  ).find(t => t.at(0)).at(1)
}

#let create_dict(default-dict, user-dict) = {
  if user-dict == none {
    return default-dict
  }

  let new-dict = default-dict
  for (key, value) in user-dict {
    if key in default-dict.keys() {
      new-dict.insert(key, value)
    }
  }
  return new-dict
}

#let setup_presentation(
  content,
  title-slide: none,
  footer: none,
  height: 12cm,
  theme: none,
  table-of-content: false,
  header: true,
  locale: "EN"
) = {
  assert(locale in ("RU", "EN"))

  let default-title-slide = (
    enable: false,
    title: none,
    authors: none, 
    institute: none,
  )
  title-slide = create_dict(default-title-slide, title-slide)

  let default-footer = (
    enable: false,
    title: none,
    institute: none,
    authors: (),
    date: today(locale),
  )
  footer = create_dict(default-footer, footer)

  let theme-default = (
    primary: rgb("#003365"),
    secondary: rgb("#00649F"),
    background: rgb("#FFFFFF"),
    main-text: rgb("#000000"),
    sub-text: rgb("#FFFFFF"),
    sub-text-dimmed: rgb("#FFFFFF"),
//    accent: rgb("#FF9900")     
  )
  theme = create_dict(theme-default, theme)

  set text(size: 14pt, fill: theme.main-text)

  let authors_short_len = {
    if footer.authors.len() > 0 {
      footer.authors.join().len()
    } else {
      0
    }
  }

  let header_box = box(
    width: 100%,
    outset: (left: 2em, right: 2em, top: 1em, bottom: 0.2em),
    fill: rgb("#142d69"),
    create_header(theme)
  )



  set page(
    width: height * 16 / 10,
    height: height,
    fill: theme.background,
    margin: (
      top: 0em,
      right: 1em, left: 1em, 
      bottom: {if footer.enable {1.2em + int(authors_short_len/15)*0.9em} else {0em}}),
    //Footer
    footer: context{
      if footer.enable {
        if here().page() == 1 {
          []
        } else {
          grid(
            columns: 3,
            inset: -1pt, 
            align: (left + horizon, center + top, top),
            box(
              fill: rgb(theme.primary),
              width: 100%,
              height: 100%,
              outset: (bottom: 1em, left: 0.5cm, top: 0.1cm),
            )[
              #v(-0.1em)
              #if footer.authors.len() > 0 {
                text(fill: theme.sub-text)[
                  #grid(
                    columns: 2, 
                    align: (center+horizon, center+horizon),
                    box(width: 100%, height: 100%)[
                      #align(horizon, text(fill: theme.sub-text)[
                        #set par(leading: 0.2em)
                        #footer.authors.join(", ")
                      ])
                    ],
                    box(width: 5em, height: 100%)[
                        #text[#footer.institute]
                    ])
                  ]
                } else {
                  align(center+horizon, text(fill: theme.sub-text)[
                    #text[#footer.institute]
                  ])
                }
              ],
            box(
              fill: rgb("#0064A0"),
              width: 100%,
              height: 100%,
              outset: (bottom: 1em, top: 0.1cm),
            )[
              #align(horizon, text(fill: theme.sub-text)[
                #v(-0.1em)
                #footer.title
              ])
            ],
            box(
              fill: rgb(theme.primary),
              width: 100%,
              height: 100%,
              outset: (bottom: 1em, top: 0.1cm, right: 1cm),
            )[
              #v(-0.1em)
              #grid(
                columns: 2, 
                align: (left+horizon, right+horizon),
                box(width: 100%, height: 100%)[~#text(fill: theme.sub-text)[#footer.date]],
                box(width: 10%, height: 100%)[
                  #align(horizon, text(fill: theme.sub-text)[
                    #v(-0.1em)
                    #counter(page).display("1/1", both: true);
                  ])
                ])
              ],
            )
          }
        }
      },
      //Header
      header: none, 
    )

    // Title slide
    {
      if title-slide.enable {
        set page(
          header: none,
          footer: none,
        )
        align(center + horizon, box(
          fill: theme.primary,
          radius: 15pt,
          inset: 2em,
          width: 100%,
          text(size: 2.2em, weight: "bold", fill: theme.sub-text)[#title-slide.title],
        ))
        align(center, text(size: 1.8em)[#title-slide.authors.join(", ")])
        align(center, text(size: 1.4em)[#title-slide.institute])
      }
    }

    //Table of content
    if table-of-content {
      set page(header: none)

      show outline.entry.where(level: 1): set text(size: 1.6em)
      show outline.entry.where(level: 2): set text(size: 1.2em)

      show outline.entry: it => {
        if it.element.body == [] {
          none  
        } else {
          it
        }
      }

      set align(center)
      text(size: 2.2em)[
        #v(0.2em)
        #{
          (
            (locale == "EN", [*Table of contents*]),
            (locale == "RU", [*Оглавление*])
          ).find(t => t.at(0)).at(1)
        }
      ]
      columns(2, outline(depth: 2, title: none))
    }

    //Section slide
    show heading.where(level: 1): x => {
      pagebreak(weak: true)

      set page(header: none)

      let name = x.body.text

      align(center + horizon, box(
        fill: theme.primary,
        radius: 15pt,
        inset: 2em,
        width: 100%,
        text(size: 2.2em, weight: "bold", fill: theme.sub-text)[#name],
      ))
    }

    // Main slide
    let slide(title) = {
      pagebreak(weak: true)

      if header {
        grid(
          box(
            width: 100%,
            outset: (left: 2em, right: 2em, top: 1em, bottom: 0.2em),
            fill: rgb("#142d69"),
          )[
            #create_header(theme)
          ],
        )
      }

      set align(center)
      set text(size: 20pt)
      box(
        inset: 0.2em,
        text(weight: "bold")[#title],
      )

    }
    show heading.where(level: 2): x => {
      slide(x.body)
    }
    show heading.where(level: 3): x => {
      slide(x.body)
    }

    content
  }

#show raw.where(block: false): box.with(
  fill: luma(240),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 5pt,
)

#set par(first-line-indent: (amount: 1em, all: true), justify: true)


#let pepentation_block(col: gray, raw_col: none, content) = {
  if raw_col == none {
    raw_col = col
  }

  show raw.where(block: false): it => box(
    fill: luma(240).rgb().mix(raw_col),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 5pt,
    it.text
  )

  box(
    fill: col.transparentize(80%),
    radius: 1em,
    outset: 0.5em,
    text[#content]
  )
}

#let defenition(content) = {
  pepentation_block[#content]
}

#let warning(content) = {
  pepentation_block(col: red)[#content]
}

#let remark(content) = {
  pepentation_block(col: orange)[#content]
}

#let hint(content) = {
  pepentation_block(col: green)[#content]
}
