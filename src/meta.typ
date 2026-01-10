// index.typ
#import "@preview/cetz:0.4.2": canvas, draw, tree
#import "@preview/wordometer:0.1.5": total-words
#import "setup.typ": format, center, right
#show: format

#set document(
    title: [meta]
)

#line(length: 100%)

= An Autology

In my pursuit of generating websites explicitly in the manner I prefer , I end up using unorthodoxing methods of generating a website.

If you've taken a look at the source for this website, linked in the bottom left corner, you might ask yourself

== Why use Typst to generate a website?

With the power of Typst, I can quite simply illustrate

#figure(
    canvas(length: 2cm, {
        import draw: *
        let phi = (1 + calc.sqrt(5)) / 2

        ortho({
            hide({
                line(
                    (-phi, -1, 0), (-phi, 1, 0), (phi, 1, 0), (phi, -1, 0), close: true, name: "xy",
                )
                line(
                    (-1, 0, -phi), (1, 0, -phi), (1, 0, phi), (-1, 0, phi), close: true, name: "xz",
                )
                line(
                    (0, -phi, -1), (0, -phi, 1), (0, phi, 1), (0, phi, -1), close: true, name: "yz",
                )
            })

            intersections("a", "yz", "xy")
            intersections("b", "xz", "yz")
            intersections("c", "xy", "xz")

            set-style(stroke: (thickness: 0.5pt, cap: "round", join: "round"))
            line((0, 0, 0), "c.1", (phi, 1, 0), (phi, -1, 0), "c.3")
            line("c.0", (-phi, 1, 0), "a.2")
            line((0, 0, 0), "b.1", (1, 0, phi), (-1, 0, phi), "b.3")
            line("b.0", (1, 0, -phi), "c.2")
            line((0, 0, 0), "a.1", (0, phi, 1), (0, phi, -1), "a.3")
            line("a.0", (0, -phi, 1), "b.2")

            anchor("A", (0, phi, 1))
            content("A", [$A$], anchor: "north", padding: .1)
            anchor("B", (-1, 0, phi))
            content("B", [$B$], anchor: "south", padding: .1)
            anchor("C", (1, 0, phi))
            content("C", [$C$], anchor: "south", padding: .1)
            line("A", "B", stroke: (dash: "dashed"))
            line("A", "C", stroke: (dash: "dashed"))
        })
    })
)

or communicate in the most beautiful language

$ a_0 (x) (dif ^n y)/(dif x^n) + a_1 (x) (dif ^(n-1) y)/(dif x^(n-1)) + ...  + a_(n-1)(x)(dif y)/(dif x) + a_n (x)y = r(x) $

For those not in the know #link("https://typst.app")[Typst] is a modern alternative to #link("https://www.latex-project.org")[LaTeX]. These two are software primarily designed to prepare professional or academic documents

Before the birth of this website, I mostly wrote prose with #link("https://orgmode.org/")[org-mode]. The files would be parsed using a rust program into HTML and then rendered on my website (refer to webx below).

But recently, I've been wanting to publish more formal work as well, for example the #link("https://www.ibo.org/programmes/diploma-programme/curriculum/dp-core/extended-essay/")[Extended Essay] I wrote for my #link("https://www.ibo.org/programmes/diploma-programme/")[International Baccaleurate Diploma] on using ordinary differential equations to model electrical filters.

Ever since 2023, I've been learning and using Typst frequently to prepare my documents. I've watched Typst and its ecosystem grow from practically nothing. Not only is Typst strong right now, but its future is especially bright as adoption increases.

With the release of #link("https://typst.app/blog/2025/typst-0.14/#richer-html-export")[Typst 0.14], the typst HTML export api is more mature. So I decided to take the leap, although many things are still not complete like compiling a directory of Typst files to html. I hope through my early buy-in, pioneer the development of Typst as a static site generator.

== How exactly does this work?

I wouldn't exactly like to answer this question until my workflow is more concrete, but at a base, we compile individual typst files into html and layer css.

Specific compilation tooling can be seen in #link("https://github.com/wylited/weby/blob/main/setup.typ")[setup.typ], for example math blocks are rendered as SVGs, for now...

This part of the autology is a work in process, as I would like to finish some other features before updating it.

== Naming Patterns

My first personal website (that I'm proud enough to claim my own), was named #link("https://github.com/wylited/webx")[webx] for its (ab)use of #link("https://htmx.org/")[htmx]. Later, I'll discuss in depth my (ab)use of vercel serverless rust functions to generate an entire static site.

Likewise, since I now use to Typst to generate my website, _weby_ not only sequentially follows _webx_, but also uses the *y* from Typst, alike to using *x* from htmx.

== What was webx?

I really didn't want to use javascript to make a cool website. As you might know I'm a massive rust fan, so I tried to write as much of my website in rust as possible, while also minimizing functionality loss that I would have in a regular JS framework.

I stumbled across #link("https://github.com/vercel-community/rust")[rust serverless functions]. I'm still not sure what a Vercel Function is, but when I saw that it could take a rust program and serve it at an endpoint my first thought was "could I serve an entire website on that?" (yes, yes you can).

So at each endpoint, we have a minimal #link("https://en.wikipedia.org/wiki/Template_processor")[templating] engine running to output the content of the website. Each page is represented by a binary compiled to that endpoint. This approach was actually quite refreshing compared to the typical router approach taken for building an API in Rust.

Honestly, I would have lost alot of functionality without #link("https://htmx.org/")[htmx] and #link("https://leanrada.com/htmz/")[htmz]. With these, I could update the #link("https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model")[DOM] on the fly without having to rely at all javascript which was a game changer.

Designwise, webx took a prety terminal like approach with #link("https://www.jetbrains.com/lp/mono/")[JetBrains Mono] #link("https://www.nerdfonts.com/")[Nerd font] and a colorscheme from #link("https://github.com/dempfi/ayu")[ayu-light] (my favorite theme).

I added a few gimmicks on top that I liked, for example a song player for #link("https://www.youtube.com/watch?v=KhBKA2JfFKI")[When I 226], which is a great song. A dark and light theme transitioner, which I also plan to implement for this website. As well as a cool transition, for which I have no idea how to describe, between navigating different pages.

However, there were quite a few downsides to webx:
1. The serverless functions would be compiled on the first call after a long time. Thus, if my website hadn't been visited in a while, it would take a few seconds to load all the pages again and be quite annoying.
2. My website acted more or less like an #link("https://en.wikipedia.org/wiki/Single-page_application")[SPA] without history. This would cause issues for users when they tried to share links or navigate back pages.

#sym.copyright 2025 #link("https://github.com/wylited/weby")[weby] #right[#total-words Words]
#line(length: 100%)
