// #import "@preview/clean-math-paper:0.2.4": *
#import "setup.typ": format, center, right, title
#show: format

// // Modify some arguments, which can be overwritten in the template call
// #page-args.insert("numbering", "1/1")
// #text-args-title.insert("size", 2em)
// #text-args-title.insert("fill", black)
// #text-args-authors.insert("size", 12pt)

// #show: template.with(
//   title: "Fractional RSA, COMP2633 Week 8 Homework B",
//   authors: (
//     (name: "Dhairya Shah"),
//   ),
//     date: [November 15th, 2025],
//   heading-color: rgb("#101090"),
//   link-color: rgb("#008002"),
//   abstract: [
// _Finding inverses of e modulo (p-1)(q-1) is too complicated.\ We can just use d = 1 / e._
// ],
//   keywords: ("Crypto", "RSA", "Oracle"),
// )

#set document(
    title: [Fractional RSA\ COMP2633 Wk8 HwB]
)

#set heading(numbering: "1.")


#line(length: 100%)

// TODO Replace with #title once we get to a newer typst version
#title()

#line(length: 100%)

= Preface

Challenge authored by Tom Yueng, Firebird Core member.

14 solves. First blood in 24 minutes.

= Analysis

The challenge implements a variation of RSA, so called "Fractional RSA". Normally the setup for RSA uses:
- A public key $(n, e)$, where $n = p dot q$ the product of two large distinct primes and $e$ is an integer coprime to $n$.
- Encryption $ c = m^e mod n $
- Decryption, where $d$ is the modular inverse of $e mod phi(n)$$ m = c^d mod n $
- $phi(n)$ is the number of integers smaller than n that are coprime to it. For $n = p dot q$, we can show that $phi(n) = (p-1)(q-1)$.

However, in this challenge:
- $n$ is the product of 10 distinct primes, each 256 bits.
- The public exponent is set to $e = 65537$.
- We are given the ciphertext $c = m^e mod n$, where $m$ is the flag.
- #[
    The server offers an oracle with two operations:
    1. Encrypt with $e = 2$, i.e returns $m^2 mod n$.
    2. Decrypt with $d = 1/2$, i.e returns $sqrt(c) mod n$.
]
Furthermore, the modulus $n$ is hidden, and we are only allowed 20 queries.

= The Vulnerability

RSA depends on $n$ being difficult to factor, thus it is difficult to compute $phi(n)$ and you cannot determine $d equiv e mod phi(n)$ for decryption.

However, if we have all the 10 factors,
$ n = a dot b dot c dot d dot e dot f dot g dot h dot i dot j $

Then we know that,

$
    phi(n) = (a-1)(b-1)(c-1)(d-1)(e-1)(f-1)(g-1)(h-1)(i-1)(j-1)
$

Since the servers oracle allows us to compute the square root of integers $mod n$, we can exploit this to factor $n$.

= The Attack Vector
== Step 1: Recover N
The encryption oracle computes $c equiv m^2 mod n$, so for large random $m$:
$ m^2 - c = k dot n $

Thus we can compute $a = m^2 - c$ for several random $m$.

Then take the $gcd(a_1, a_2, ..., a_k)$ to recover $n$.

This is because $k dot n$ will likely be different for each $m$.

If $gcd(k_1, k_2, ..., k_k) = 1$, then $gcd(a_1, a_2, ..., a_k) = n$.

== Step 2: Factoring N
Now that we have $n$, we can use the decryption oracle to factor it.

It may not seem obvious that we need to do this, however if you look at how the decryption oracle works

```
def sqrt_mod_n(a, ps):
    residues = []
    for p in ps:
        q = nthroot_mod(a, 2, p)
        if q is None:
            return -1
        else:
            residues.append(q)
    return int(crt(ps, residues)[0])
```

$p s$ is the list of prime factors of $n$. Thus, the decryption oracle is actually computing the square root $mod$ each prime factor of $n$ and then combining them using the Chinese Remainder Theorem.

This gives the hint that we can use the square root oracle to factor n.

To factor $n$, we will start with the following approach:
- Pick a large random $x$.
- Locally compute $c = x^2 mod n$.
- Query the oracle for the decryption of $sqrt(c)$

Why query the oracle for decryption?

Encryption with $e = 1/2$ means $c = sqrt(m) mod n$.

So instead when we input $sqrt(c)$, then $sqrt(c) equiv sqrt(m) mod n$.

Let $y = sqrt(m)$, then we know that $y^2 equiv c equiv x^2 mod n$. And further,

$
    y^2 &equiv x^2 mod n \
    y^2 dot x^-2 &equiv 1 mod n \
    (y dot x^-1)^2 &equiv 1 mod n
$

Let $s = y dot x^(-1)$, then

$
    s^2 &equiv 1 mod n \
    s^2 - 1 &equiv 0 mod n \
    (s-1)(s+1) &equiv 0 mod n \
$

Now we have two factors of $n$, we can further make use GCD to determine the prime factors,

$ gcd(s+1, n) "and" gcd(s-1, n) $

This is because for each prime $p_i | n$, since $s^2 mod p_i equiv 1$, $s mod p_i$ is either $plus.minus 1$.
- If $s equiv 1 mod p_i$, then $p_i | (s-1)$
- If $s equiv -1 mod p_i$, then $p_i | (s+1)$

So, $gcd(s+1, n)$ will be the product of all $p_i | (s-1)$, while $gcd(s-1, n)$ will be the product of all $p_i | (s+1)$.

Since we can split $n$ into two composite factors, by repeating this process we but instead taking the gcd against the composite factors of n, we can factorize $n$ into its 10 prime factors.

In the ideal case, we would need $log_2(10) approx 4$ queries to fully factor $n$. So accounting for randomness we can expect to factor $n$ within 8-12 queries.

=== The Edge Case
You may notice that if $s^2 = 1$, i.e. $x^2 equiv y^2 mod n$ then this won't work.

This doesn't matter much as we can prove that it is quite rare that $x^2 equiv y^2 mod n$ by looking at the code of the square root oracle.

Since the square root oracle takes the square root of our input modulo each prime factor.

For each prime factor $p_i$, $a^2$ would have two roots $plus.minus a mod p$.

When we combine these via CRT, there are $2^10 = 1024$ possiblities of $y^2 mod n$

So there is a $1/1024 approx 0.1%$ chance that $y^2 equiv x^2 mod n$


= Decrypting the flag

As we said earlier, $phi(n) = (p_1-1)(p_2-1)...(p_(10)-1)$.

We just need to compute $d equiv e^(-1) mod phi(n)$.

Then we can trivially decrypt the flag with $ m = c^d mod n $

#line(length: 100%)
