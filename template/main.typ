#import "@local/pepentation:0.0.1": *

#show: setup_presentation.with(
  title-slide: (
    enable: true,
    title: "Long version of the title",
    authors: ("LastName1 FirstName1", "LastName2 FirstName2"),
    institute: "University of SWAG",
  ),
  footer: (
    enable: true,
    title: "Title",
    institute: "USWAG",
    authors: ("Author1", "Author2"),
  ),
  table-of-content: true, // Table of contents is interactive btw. You can click to move to a selected slide
  header: true,
  locale: "EN"
)

= Section Name

== Slide Title

#lorem(100)

//If no title is provided it will not be shown in table of content
==

= Another Section

== Another Slide
