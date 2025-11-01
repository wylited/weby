// setup.typ
// adapted from https://github.com/typst/typst/issues/721#issuecomment-3064895139
#import "@preview/wordometer:0.1.5": word-count

#let format(doc) = {
    // inline math equation
    show math.equation.where(block: false): it => {
        if target() == "html" {
            html.elem("span", attrs: (class: "math"), html.frame(it))
        } else {
            it
        }
    }

    // block math equation
    show math.equation.where(block: true): it => {
        if target() == "html" {
            html.elem("figure", attrs: (class: "math"), html.frame(it))
        } else {
            it
        }
    }

    // make links open in a new tab
    show link: it => {
        if target() == "html"{
            html.elem("a", attrs: (class: "link", target: "_blank"), it)
        } else {
            it
        }
    }

    // horizontal rule
    show line.where(length: 100%): it => {
        if target() == "html" {
            html.elem("hr")
        } else {
            it
        }
    }

    // for styling, use `where` to assign classes for different types of figure
    show figure: it => {
        if target() == "html" {
            html.elem("figure", attrs: (class: "typst"), html.frame(it))
        } else {
            it
        }
    }

    show: word-count

    // TODO update these to #html.link()[] and #html.base()[] and place them in head
    html.elem("link", attrs: (rel: "icon", type: "image/x-icon", href: "favicon.ico"))
    html.elem("link", attrs: (rel: "stylesheet", href: "styles.css"))[]
    html.elem("base", attrs: (target: "_blank"))[]
    doc
}

#let center(body) = context {
    if target() == "html" {
        html.elem("div", attrs: (class: "center"), body)
    } else {
        align(center)[body]
    }
}

#let right(body) = context {
    if target() == "html" {
        html.elem("span", attrs: (class: "right"), body)
    } else {
        [h(1fr) body]
    }
}
