#' Apply a function within each row
#'
#' Create efficiently new column(s) in data frame (including tibble) by applying a function one row
#' at a time.
#'
#' `lay()` create a vector or a data frame (or tibble), by considering in turns each row of a data
#' frame (`.data`) as the vector input of some function(s) `.fn`.
#'
#' This makes the creation of new columns based on a rowwise operation both simple (see
#' **Examples**; below) and efficient (see the Article [**benchmarks**](https://courtiol.github.io/lay/articles/benchmarks.html)).
#'
#' The function should be fully compatible with `{dplyr}`-based workflows and follows a syntax close
#' to [dplyr::across()].
#'
#' Yet, it takes `.data` instead of `.cols` as a main argument, which makes it possible to also use
#' `lay()` outside `dplyr` verbs (see **Examples**).
#'
#' The function `lay()` should work in a wide range of situations, provided that:
#'
#' - The input `.data` should be a data frame (including tibble) with columns of same class, or of
#' classes similar enough to be easily coerced into a single class. Note that `.method = "apply"`
#' also allows for the input to be a matrix and is more permissive in terms of data coercion.
#'
#' - The output of `.fn` should be a scalar (i.e., vector of length 1) or a 1 row data frame (or
#' tibble).
#'
#' If you use `lay()` within [dplyr::mutate()], make sure that the data used by [dplyr::mutate()]
#' contain no row-grouping, i.e., what is passed to `.data` in [dplyr::mutate()] should not be of
#' class `grouped_df` or `rowwise_df`. If it is, `lay()` will be called multiple times, which will
#' slow down the computation despite not influencing the output.
#'
#'
#' @param .data A data frame or tibble (or other data frame extensions).
#' @param .fn A function to apply to each row of `.data`.
#' Possible values are:
#'
#'   - A function, e.g. `mean`
#'   - An anonymous function, .e.g. `function(x) mean(x, na.rm = TRUE)`
#'   - An anonymous function with shorthand, .e.g. `\(x) mean(x, na.rm = TRUE)`
#'   - A purrr-style lambda, e.g. `~ mean(.x, na.rm = TRUE)`
#'
#'     (wrap the output in a data frame to apply several functions at once, e.g.
#'     `~ tibble(min = min(.x), max = max(.x))`)
#'
#' @param ... Additional arguments for the function calls in `.fn` (must be named!).
#' @param .method This is an experimental argument that allows you to control which internal method
#'   is used to apply the rowwise job:
#'   - "apply", the default internally uses the function [apply()].
#'   - "tidy", internally uses [purrr::pmap()] and is stricter with respect to class coercion
#'   across columns.
#'
#'   The default has been chosen based on these [**benchmarks**](https://courtiol.github.io/lay/articles/benchmarks.html).
#'
#' @return A vector with one element per row of `.data`, or a data frame (or tibble) with one row per row of `.data`. The class of the output is determined by `.fn`.
#'
#' @importFrom vctrs vec_c
#' @importFrom rlang list2 exec as_function
#' @importFrom purrr pmap
#'
#' @examples
#'
#' # usage without dplyr -------------------------------------------------------------------------
#'
#' # lay can return a vector
#' lay(drugs[1:10, -1], any)
#'
#' # lay can return a data frame
#' ## using the shorthand function syntax \(x) .fn(x)
#' lay(drugs[1:10, -1],
#'    \(x) data.frame(drugs_taken = sum(x), drugs_not_taken = sum(x == 0)))
#'
#' ## using the rlang lambda syntax ~ fn(.x)
#' lay(drugs[1:10, -1],
#'    ~ data.frame(drugs_taken = sum(.x), drugs_not_taken = sum(.x == 0)))
#'
#' # lay can be used to augment a data frame
#' cbind(drugs[1:10, ],
#'       lay(drugs[1:10, -1],
#'          ~ data.frame(drugs_taken = sum(.x), drugs_not_taken = sum(.x == 0))))
#'
#'
#' # usage with dplyr ----------------------------------------------------------------------------
#'
#' if (require("dplyr")) {
#'
#'   # apply any() to each row
#'   drugs |>
#'     mutate(everused = lay(pick(-caseid), any))
#'
#'   # apply any() to each row using all columns
#'   drugs |>
#'     select(-caseid) |>
#'     mutate(everused = lay(pick(everything()), any))
#'
#'   # a workaround would be to use `rowSums`
#'   drugs |>
#'     mutate(everused = rowSums(pick(-caseid)) > 0)
#'
#'   # but we can lay any function taking a vector as input, e.g. median
#'   drugs |>
#'     mutate(used_median = lay(pick(-caseid), median))
#'
#'   # you can pass arguments to the function
#'   drugs_with_NA <- drugs
#'   drugs_with_NA[1, 2] <- NA
#'
#'   drugs_with_NA |>
#'     mutate(everused = lay(pick(-caseid), any))
#'   drugs_with_NA |>
#'     mutate(everused = lay(pick(-caseid), any, na.rm = TRUE))
#'
#'   # you can lay the output into a 1-row tibble (or data.frame)
#'   # if you want to apply multiple functions
#'   drugs |>
#'     mutate(lay(pick(-caseid),
#'              ~ tibble(drugs_taken = sum(.x), drugs_not_taken = sum(.x == 0))))
#'
#'   # note that naming the output prevent the automatic splicing and you obtain a df-column
#'   drugs |>
#'     mutate(usage = lay(pick(-caseid),
#'               ~ tibble(drugs_taken = sum(.x), drugs_not_taken = sum(.x == 0))))
#'
#'   # if your function returns a vector longer than a scalar, you should turn the output
#'   # into a tibble, which is the job of as_tibble_row()
#'   drugs |>
#'     mutate(lay(pick(-caseid), ~ as_tibble_row(quantile(.x))))
#'
#'   # note that you could also wrap the output in a list and name it to obtain a list-column
#'   drugs |>
#'     mutate(usage_quantiles = lay(pick(-caseid), ~ list(quantile(.x))))
#' }
#'
#' @export
lay <- function(.data, .fn, ..., .method = c("apply", "tidy")) {

  method <- match.arg(.method)[1]

  fn <- as_function(.fn)

  if (method == "tidy") {

    args <- list2(...)
    bits <- pmap(.data, function(...) exec(fn, vec_c(...), !!!args))

  } else if (method == "apply") {

    bits <- apply(.data, 1L, fn, ...)

  } else stop(".method input unknown")

  vec_c(!!!bits)
}
