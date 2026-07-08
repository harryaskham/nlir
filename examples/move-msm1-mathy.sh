#!/usr/bin/env bash
# nlir showcase · msm1 · DET-MATH — exact math a prompt can't be trusted to compute
#
# Harry asked for interesting *mathy* use cases. This gallery is the DET-MATH family:
# ranges, set cardinality, and arithmetic folds — every line is deterministic, runs
# OFFLINE (no API key), and is EXACT. That is the point: unlike "ask a model for the
# sum of the first 100 numbers" (which can slip), these compute the real answer and
# are hard-assertable in CI — identical on every run, on every transport, zero model risk.
#
# The mathy round (2026-07-08) turned play into landed capability:
#   a..b     numeric range literal     1..5 -> [1,2,3,4,5]   (aur-1, c790621)
#   $len     length / cardinality       $len%coll -> Number  (msm1, 568a01b)
#   ∪ ∩ ∖ ∈  set algebra as math        $union/$inter/$diff/$elem   (bd-49d65a)
#
# Together they read like maths: "count the intersection", "sum the range", "fold the
# product". See move-msm1-sets.sh for the set-algebra gallery it builds on.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
why() { printf '   \033[2m(%s)\033[0m\n' "$1"; }
# runlit EXPR — evaluate a literal deterministic expression (no stdin).
runlit() { printf '  => '; "$NLIR" --config "$CFG" --mode det --quiet -e "$1" 2>&1 | paste -sd' ' -; }

say "RANGES — a sequence from two integers"
why "numeric a..b is a range literal; a>b counts down (free reverse ranges)"
runlit '1..5'                                        # -> 1 2 3 4 5
runlit '5..1'                                        # -> 5 4 3 2 1  (descending)

say "GAUSS — the sum of 1..100, computed not recalled"
why "\$fold folds + over the range: 5050, exact. A prompt would have to trust its arithmetic; nlir does the math."
runlit '$fold%({$0+$1},1..100)'                      # -> 5050

say "CARDINALITY — how big is a set? (\$len)"
why "\$len is the model-free counting primitive: list items, dict keys, else char count"
runlit '$len%(1..100)'                               # -> 100  (a hundred numbers)
runlit '$len%($inter%([2,3,5,7,11],1..10))'          # -> 4    (how many primes are <= 10)
runlit '$len%($diff%(1..10,[2,4,6,8,10]))'           # -> 5    (how many odd numbers 1-10)

say "SUM OF SQUARES — map then fold over a range"
why "\$map squares each element, \$fold sums them — 1²+2²+3²+4²+5² = 55, exact"
runlit '$fold%({$0+$1},$map%({$0*$0},1..5))'         # -> 55

say "FACTORIAL — 5! as a fold-product of the range"
why "the product of 1..5 IS 5! — fold * over the range, no lookup"
runlit '$fold%({$0*$1},1..5)'                        # -> 120

say "RUNNING FACTORIALS — \$scan keeps every prefix product"
why "\$scan is fold that emits each step: 1!, 2!, 3!, 4!, 5!"
runlit '$scan%({$0*$1},1..5)'                        # -> 1 2 6 24 120

say "MEAN / STATISTICS — sum over count (unlocked by \$len)"
why "\$fold sums, \$len counts, / divides — the exact average of 1..100, model-free (credit @aur-0)"
runlit '$fold%({$0+$1},1..100)/$len%(1..100)'        # -> 50.5
runlit '$fold%({$0+$1},[2,4,6,8,10])/$len%([2,4,6,8,10])'  # -> 6   (mean of the evens)

say "ITERATION — do-N: repeated application, a power without a power op"
why "{f}_N applies f N times; ten doublings of 1 = 2^10"
runlit '({$0*2}_10)%1'                                # -> 1024   (2^10)
runlit '({$0+$0}_5)%1'                                # -> 32     (2^5 by self-addition)

say "PREDICATE-FILTERED AGGREGATE — sum-if / count-if with strict \$gt"
why "fold-fusion scales each elem by its predicate (true=1): the sum of the elements > 5"
runlit '{$0+$1*($gt%($1,5))}⊘[0,3,6,9]'              # -> 15   (6+9)
runlit '$fold%({$0+$1},$map%({$gt%($0,5)},1..10))'   # -> 5    (how many are > 5)

say "BOOLEAN PREDICATE LOGIC — compose comparisons with ∧ / \$not"
why "strict comparisons return clean Bools that AND / negate directly"
runlit '($gt%(5,3))∧($lt%(2,4))'                     # -> true
runlit '$not%($gt%(3,5))'                            # -> true

say "SELF-REFERENTIAL STAT — count the values above the list's OWN mean"
why "bind the mean, then \$filter with \$gt against it: range + fold + \$len (twice) + \$gt in one query (credit @msm-0)"
runlit 'm=$fold%({$0+$1},1..10)/$len%(1..10); $len%($filter%({$gt%($0,$m)},1..10))'   # -> 5   (mean 5.5; 6,7,8,9,10 exceed it)

say "ORDER STATISTICS — max/min are just sort + index (no special functions)"
why "\$sort is numeric; take the last for max, the first for min — max = sort-then-last"
runlit '$nth%(-1,$sort%[3,1,4,1,5,9,2,6])'           # -> 9   (max)
runlit '$nth%(0,$sort%[3,1,4,1,5,9,2,6])'            # -> 1   (min)

say "MEDIAN — sort + the middle index, ONE line for both parities (needs \$floor/\$ceil)"
why "floor & ceil of (len-1)/2 coincide when odd, straddle when even = mean of the two middles (credit @msm-0)"
runlit 'L=[3,1,4,1,5];($nth%($floor%(($len%$L-1)/2),$sort%$L)+$nth%($ceil%(($len%$L-1)/2),$sort%$L))/2'   # -> 3   (odd)
runlit 'L=[10,2,8,4];($nth%($floor%(($len%$L-1)/2),$sort%$L)+$nth%($ceil%(($len%$L-1)/2),$sort%$L))/2'   # -> 6   (even: (4+8)/2)

say "∀ / ∃ — quantifiers: fold each element's yes/no into one verdict"
why "map a strict predicate over the list, then fold ∧ (all) or ∨ (any)"
runlit '$fold%({$0∧$1},$map%({$lt%($0,100)},[3,50,99]))'   # -> true   (are all < 100?)
runlit '$fold%({$0∨$1},$map%({$lt%($0,0)},[3,-2,5]))'      # -> true   (is any < 0?)

say "real statistics — max, median, ∀/∃ — fall out of sort + index + fold, exact and model-free."

say "GEOMETRY & DEVIATION — one unary primitive (\$sqrt) unlocks a whole family"
why "variance already composes: bind the mean, average the squared deviations — no new builtin"
runlit 'L=[2,4,4,4,5,5,7,9];m=$fold%({$0+$1},$L)/$len%$L;$fold%({$0+$1},$map%({($0-$m)*($0-$m)},$L))/$len%$L'   # -> 4   (variance)
why "so STANDARD DEVIATION is one \$sqrt away — wrap the variance (credit @msm-0's narration)"
runlit 'L=[2,4,4,4,5,5,7,9];m=$fold%({$0+$1},$L)/$len%$L;$sqrt%($fold%({$0+$1},$map%({($0-$m)*($0-$m)},$L))/$len%$L)'   # -> 2   (stddev)
why "the same \$sqrt gives Pythagoras, Euclidean distance, and the geometric mean"
runlit '$sqrt%(3*3+4*4)'                          # -> 5   (hypotenuse of a 3-4 right triangle)
runlit '$sqrt%((4-1)*(4-1)+(6-2)*(6-2))'          # -> 5   (distance (1,2)->(4,6))
runlit '$sqrt%(4*9)'                              # -> 6   (geometric mean of 4 and 9)

say "stddev = the square root of variance — geometry and statistics fall out of one primitive, exact and model-free."

say "NUMBER THEORY — \$mod (credit @msm-3) opens even/odd, divisibility, cyclic arithmetic"
why "\$mod is non-negative (rem_euclid); is-even = \$not%(\$mod%(n,2)) since 0 is falsy"
runlit '$mod%(17,5)'                                  # -> 2    (17 mod 5)
runlit '$len%($filter%({$not%($mod%($0,2))},1..10))'  # -> 5    (count of evens in 1..10)
runlit '$mod%(10+5,12)'                               # -> 3    (clock arithmetic: hour 15 wraps to 3 on a 12-clock)

say "PRIMALITY by trial division — nlir DERIVES it, never recalls it (credit @aur-0)"
why "a prime has exactly two divisors (1 and itself): count the divisors in 1..N, check ==2"
runlit '$len%($filter%({$not%($mod%(7,$0))},1..7))==2'    # -> true    (7 is prime)
runlit '$len%($filter%({$not%($mod%(8,$0))},1..8))==2'    # -> false   (8 has divisors 1,2,4,8 — composite)
runlit '$len%($filter%({$not%($mod%(13,$0))},1..13))==2'  # -> true    (13 is prime)

say "FIZZBUZZ — the whole classic in one line: map the nested-\$if over 1..15"
why "per element: FizzBuzz if 15 divides it, else Fizz if 3, else Buzz if 5, else the number"
runlit '$map%({$if%($not%($mod%($0,15)),"FizzBuzz",$if%($not%($mod%($0,3)),"Fizz",$if%($not%($mod%($0,5)),"Buzz",$0)))},1..15)'   # -> 1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz

say "PROJECT EULER #1 — sum of every multiple of 3 or 5 below N, exact"
why "filter the range by (3 divides it ∨ 5 divides it), then fold +"
runlit '$fold%({$0+$1},$filter%({($not%($mod%($0,3)))∨($not%($mod%($0,5)))},1..9))'      # -> 23      (below 10)
runlit '$fold%({$0+$1},$filter%({($not%($mod%($0,3)))∨($not%($mod%($0,5)))},1..999))'    # -> 233168   (below 1000)

say "number theory — even/odd, FizzBuzz, Project Euler #1 — exact and model-free from \$mod + \$if + \$fold."
