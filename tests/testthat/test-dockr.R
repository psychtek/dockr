test_that("Docker commands work", {

  withr::with_tempdir({

    expect_type(dockr$new(process = "docker",
      commands = "info")$show_output(),
      "list")

    expect_s3_class(dockr$new(process = "docker",
      commands = "search",
      options = "rstudio")$show_output(),
      "tbl_df")

    expect_type(dockr$new(process = "docker",
      commands = "info") $show_json(),
      "character")

  },
    clean = TRUE)
})
