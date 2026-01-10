// illustrations.typ
#import "@preview/wordometer:0.1.5": total-words
#import "@preview/cetz:0.4.2": canvas, draw, vector, matrix
#import "setup.typ": format, center, right
#show: format

#set document(
    title: [Illustrations]
)

#line(length: 100%)

= A collection of Typst illustrations

== Waves

#figure(
    canvas({
        import draw: *

        ortho(y: -30deg, x: 30deg, {
            on-xz({
                grid((0,-2), (8,2), stroke: gray + .5pt)
            })

            // Draw a sine wave on the xy plane
            let wave(amplitude: 1, fill: none, phases: 2, scale: 8, samples: 100) = {
                line(..(for x in range(0, samples + 1) {
                    let x = x / samples
                    let p = (2 * phases * calc.pi) * x
                    ((x * scale, calc.sin(p) * amplitude),)
                }), fill: fill)

                let subdivs = 8
                for phase in range(0, phases) {
                    let x = phase / phases
                    for div in range(1, subdivs + 1) {
                        let p = 2 * calc.pi * (div / subdivs)
                        let y = calc.sin(p) * amplitude
                        let x = x * scale + div / subdivs * scale / phases
                        line((x, 0), (x, y), stroke: rgb(0, 0, 0, 150) + .5pt)
                    }
                }
            }

            on-xy({
                wave(amplitude: 1.6, fill: rgb(0, 0, 255, 50))
            })
            on-xz({
                wave(amplitude: 1, fill: rgb(255, 0, 0, 50))
            })
        })
    })
)

Isometric view onto waves in 3 dimensions. From the #link("https://github.com/cetz-package/cetz/blob/master/gallery/waves.typ")[Cetz Gallery].


Author: #link("https://github.com/johannes-wolf")[Johannes-wolf], (I believe).

== Icosahedron

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

Pacioli's construction of the icosahedron. From the #link("https://github.com/cetz-package/cetz/blob/master/gallery/waves.typ")[Cetz Gallery].

Author: #link("https://github.com/johannes-wolf")[Johannes-wolf], (I believe).

#line(length: 100%)
