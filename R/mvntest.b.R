
#' @importFrom jmvcore .
#' @importFrom R6 R6Class
#' @importFrom stats mahalanobis qchisq cov dnorm sd ppoints
#' @importFrom ggplot2 ggplot aes geom_point geom_abline geom_line labs facet_wrap stat_qq stat_qq_line geom_histogram after_stat geom_boxplot

mvntestClass <- if (requireNamespace("jmvcore", quietly = TRUE)) {
  R6::R6Class(
    "mvntestClass",
    inherit = mvntestBase,
    private = list(

      # ---- Initialise result structure ----
      .init = function() {
        if (is.null(self$options$vars) || length(self$options$vars) < 2)
          return()

        private$.preallocateRows(private$.rowGroups())
        if ("groupWarnings" %in% self$results$itemNames)
          self$results$remove("groupWarnings")
      },

      # ---- Main analysis ----
      .run = function() {

        if (is.null(self$options$vars) || length(self$options$vars) < 2)
          return()

        data <- private$.prepareData()
        vars <- self$options$vars
        hasGroup <- !is.null(self$options$group)
        messages <- character()

        if (hasGroup) {
          groupVar <- self$options$group
          groupFactor <- droplevels(factor(data[[groupVar]]))
          groups <- levels(groupFactor)
          splitData <- split(data[, vars, drop = FALSE], groupFactor, drop = TRUE)
          messages <- c(messages, private$.runGrouped(splitData, groups))
        } else {
          if (nrow(data) <= length(vars)) {
            jmvcore::reject(sprintf(
              "This analysis requires more complete cases than variables (%d required; %d found).",
              length(vars) + 1L,
              nrow(data)
            ))
          }
          private$.runSingle(data)
          splitData <- NULL
        }

        private$.checkpoint()

        # Store plot data only for plots the user requested.
        if (self$options$showQQPlot) {
          if (hasGroup) {
            qqDFs <- lapply(names(splitData), function(g) {
              grpData <- as.matrix(splitData[[g]])
              if (nrow(grpData) <= ncol(grpData))
                return(NULL)

              tryCatch(
                private$.qqData(grpData, group = g),
                error = function(e) {
                  messages <<- c(messages, sprintf(
                    "Multivariate Q-Q plot was skipped for group '%s': %s",
                    g,
                    conditionMessage(e)
                  ))
                  NULL
                }
              )
            })
            qqDFs <- Filter(Negate(is.null), qqDFs)
            if (length(qqDFs) > 0) {
              self$results$qqPlot$setState(list(
                qqDF = do.call(rbind, qqDFs),
                hasGroup = TRUE
              ))
            }
          } else {
            qqDF <- tryCatch(
              private$.qqData(as.matrix(data[, vars, drop = FALSE])),
              error = function(e) {
                messages <<- c(messages, sprintf(
                  "Multivariate Q-Q plot could not be produced: %s",
                  conditionMessage(e)
                ))
                NULL
              }
            )
            if (!is.null(qqDF)) {
              self$results$qqPlot$setState(list(
                qqDF = qqDF,
                hasGroup = FALSE
              ))
            }
          }
        }

        if (self$options$showUniPlots ||
            self$options$showBoxPlots ||
            self$options$showHistograms) {
          plotState <- list(
            data = as.data.frame(data[, vars, drop = FALSE]),
            vars = vars
          )
          if (self$options$showUniPlots)
            self$results$uniPlots$setState(plotState)
          if (self$options$showBoxPlots)
            self$results$boxPlots$setState(plotState)
          if (self$options$showHistograms)
            self$results$histPlots$setState(plotState)
        }

        private$.setNotices(messages)
      },

      .rowGroups = function() {
        groupVar <- self$options$group
        if (is.null(groupVar))
          return(NULL)

        cols <- c(self$options$vars, groupVar)
        data <- jmvcore::select(self$data, cols)
        if (self$options$impute == "none") {
          data <- data[complete.cases(data), , drop = FALSE]
        } else {
          data <- data[!is.na(data[[groupVar]]), , drop = FALSE]
        }

        levels(droplevels(factor(data[[groupVar]])))
      },

      .setNotices = function(messages) {
        noticeName <- "groupWarnings"
        if (noticeName %in% self$results$itemNames)
          self$results$remove(noticeName)

        messages <- unique(messages[nzchar(messages)])
        if (length(messages) == 0)
          return()

        notice <- jmvcore::Notice$new(
          options = self$options,
          name = noticeName,
          visible = TRUE,
          clearWith = "*"
        )
        notice$set(
          jmvcore::NoticeType$WARNING,
          paste(messages, collapse = "\n")
        )
        self$results$insert(1, notice)
      },

      # ---- Pre-allocate table rows ----
      .preallocateRows = function(groups) {
        vars <- self$options$vars
        hasGroup <- !is.null(groups)
        blocks <- if (hasGroup) groups else list(NULL)

        mvnLabels <- private$.mvnRowLabels()
        uniTestName <- private$.uniTestName()

        mvnTable <- self$results$mvnTable
        uniTable <- self$results$uniTable
        descTable <- self$results$descTable

        for (g in blocks) {
          for (lab in mvnLabels) {
            row <- list(test = lab)
            if (hasGroup)
              row$group <- g
            mvnTable$addRow(rowKey = private$.mvnKey(g, lab), values = row)
          }
          for (v in vars) {
            uRow <- list(test = uniTestName, var = v)
            if (hasGroup)
              uRow$group <- g
            uniTable$addRow(rowKey = private$.varKey(g, v), values = uRow)

            dRow <- list(var = v)
            if (hasGroup)
              dRow$group <- g
            descTable$addRow(rowKey = private$.varKey(g, v), values = dRow)
          }
        }
      },

      .mvnKey = function(group, label) paste0("mvn_", group, "_", label),
      .varKey = function(group, var)   paste0("var_", group, "_", var),

      .mvnRowLabels = function() {
        switch(
          self$options$mvnTest,
          hz = "Henze-Zirkler",
          mardia = c("Mardia Skewness", "Mardia Kurtosis"),
          hw = "Henze-Wagner",
          royston = "Royston",
          doornik_hansen = "Doornik-Hansen",
          energy = "E-Statistic"
        )
      },

      .uniTestName = function() {
        switch(
          self$options$univariateTest,
          AD = "Anderson-Darling",
          SW = "Shapiro-Wilk",
          SF = "Shapiro-Francia",
          CVM = "Cram\u00e9r-von Mises",
          Lillie = "Lilliefors"
        )
      },

      # ---- Prepare data ----
      # ---- Prepare data ----
      .prepareData = function() {
        vars <- self$options$vars
        groupVar <- self$options$group

        cols <- vars
        if (!is.null(groupVar))
          cols <- c(cols, groupVar)

        data <- jmvcore::select(self$data, cols)

        for (v in vars)
          data[[v]] <- jmvcore::toNumeric(data[[v]])

        if (self$options$impute == "none") {
          data <- data[complete.cases(data), , drop = FALSE]
        } else {
          if (self$options$impute == "mice" &&
              !requireNamespace("mice", quietly = TRUE)) {
            jmvcore::reject(
              "MICE imputation requires the optional 'mice' R package."
            )
          }

          numData <- data[, vars, drop = FALSE]
          numData <- tryCatch(
            impute_missing(numData, method = self$options$impute),
            error = function(e) jmvcore::reject(sprintf(
              "Missing-data imputation failed: %s",
              conditionMessage(e)
            ))
          )
          data[, vars] <- numData
          if (!is.null(groupVar))
            data <- data[!is.na(data[[groupVar]]), , drop = FALSE]
        }

        if (nrow(data) < 3) {
          jmvcore::reject(sprintf(
            "This analysis requires at least 3 complete cases (%d found).",
            nrow(data)
          ))
        }

        if (self$options$scale)
          data[, vars] <- scale(data[, vars])

        if (self$options$transform == "log") {
          data[, vars] <- apply(data[, vars, drop = FALSE], 2, log)
        } else if (self$options$transform == "sqrt") {
          data[, vars] <- apply(data[, vars, drop = FALSE], 2, sqrt)
        } else if (self$options$transform == "square") {
          data[, vars] <- apply(
            data[, vars, drop = FALSE],
            2,
            function(x) x^2
          )
        }

        if (self$options$powerFamily != "none") {
          numData <- data[, vars, drop = FALSE]
          result <- power_transform(
            numData,
            family = self$options$powerFamily,
            type = "optimal"
          )
          data[, vars] <- result$data
        }

        if (any(!is.finite(as.matrix(data[, vars, drop = FALSE])))) {
          jmvcore::reject(
            "The selected transformation produced non-finite values. Choose another transformation or adjust the data."
          )
        }

        data
      },

      # ---- Single group ----
      # ---- Single group ----
      .runSingle = function(data) {
        vars <- self$options$vars
        numData <- data[, vars, drop = FALSE]

        mvnRes <- tryCatch(
          private$.doMVNTest(numData),
          error = function(e) jmvcore::reject(sprintf(
            "The multivariate normality test could not be computed: %s",
            conditionMessage(e)
          ))
        )
        private$.fillMVNTable(mvnRes, group = NULL)

        private$.checkpoint()
        uniRes <- test_univariate_normality(
          numData,
          test = self$options$univariateTest
        )
        private$.fillUniTable(uniRes, vars, group = NULL)

        private$.checkpoint()
        if (self$options$showDescriptives) {
          descRes <- descriptives(numData)
          private$.fillDescTable(descRes, vars, group = NULL)
        }

        private$.checkpoint()
        if (self$options$outlierMethod != "none") {
          outlierRes <- mv_outlier(
            numData,
            qqplot = FALSE,
            alpha = self$options$outlierAlpha,
            method = self$options$outlierMethod
          )
          outliers <- outlierRes$outlier[
            outlierRes$outlier$Outlier == "TRUE",
            ,
            drop = FALSE
          ]
          private$.fillOutlierTable(outliers, group = NULL)
        }
      },

      # ---- Grouped analysis ----
      .runGrouped = function(splitData, groups) {
        vars <- self$options$vars
        messages <- character()

        for (g in groups) {
          private$.checkpoint()
          grpData <- splitData[[g]]

          found <- if (is.null(grpData)) 0L else nrow(grpData)
          required <- if (is.null(grpData)) length(vars) + 1L else ncol(grpData) + 1L
          if (is.null(grpData) || found < required) {
            messages <- c(messages, sprintf(
              "Group '%s' was skipped: at least %d complete cases are required (%d found).",
              g,
              required,
              found
            ))
            next
          }

          captureError <- function(label, expression) {
            tryCatch(
              {
                force(expression)
                NULL
              },
              error = function(e) sprintf(
                "Group '%s': %s failed: %s",
                g,
                label,
                conditionMessage(e)
              )
            )
          }

          message <- captureError("multivariate normality test", {
            mvnRes <- private$.doMVNTest(grpData)
            private$.fillMVNTable(mvnRes, group = g)
          })
          if (!is.null(message))
            messages <- c(messages, message)

          private$.checkpoint()
          message <- captureError("univariate normality test", {
            uniRes <- test_univariate_normality(
              grpData,
              test = self$options$univariateTest
            )
            private$.fillUniTable(uniRes, vars, group = g)
          })
          if (!is.null(message))
            messages <- c(messages, message)

          if (self$options$showDescriptives) {
            message <- captureError("descriptive statistics", {
              descRes <- descriptives(grpData)
              private$.fillDescTable(descRes, vars, group = g)
            })
            if (!is.null(message))
              messages <- c(messages, message)
          }

          private$.checkpoint()
          if (self$options$outlierMethod != "none") {
            message <- captureError("outlier detection", {
              outlierRes <- mv_outlier(
                grpData,
                qqplot = FALSE,
                alpha = self$options$outlierAlpha,
                method = self$options$outlierMethod
              )
              outliers <- outlierRes$outlier[
                outlierRes$outlier$Outlier == "TRUE",
                ,
                drop = FALSE
              ]
              private$.fillOutlierTable(outliers, group = g)
            })
            if (!is.null(message))
              messages <- c(messages, message)
          }
        }

        messages
      },

      # ---- Run MVN test ----
      .doMVNTest = function(data) {
        test <- self$options$mvnTest
        bs <- self$options$bootstrap
        B <- self$options$nBoot

        if (test == "mardia") {
          mardia(data, bootstrap = bs, B = B)
        } else if (test == "hz") {
          hz(data, bootstrap = bs, B = B)
        } else if (test == "hw") {
          hw(data, bootstrap = bs, B = B)
        } else if (test == "royston") {
          royston(data, bootstrap = bs, B = B)
        } else if (test == "doornik_hansen") {
          doornik_hansen(data, bootstrap = bs, B = B)
        } else if (test == "energy") {
          energy(data, B = B)
        }
      },

      # ---- Fill MVN table (rows pre-allocated by rowKey) ----
      .fillMVNTable = function(res, group) {
        table <- self$results$mvnTable
        for (i in seq_len(nrow(res))) {
          label <- as.character(res$Test[i])
          table$setRow(
            rowKey = private$.mvnKey(group, label),
            values = list(
              statistic = res$Statistic[i],
              pvalue = res$p.value[i],
              result = ifelse(res$p.value[i] > 0.05, "Normal", "Not normal")
            )
          )
        }
      },

      # ---- Fill univariate table ----
      .fillUniTable = function(res, vars, group) {
        table <- self$results$uniTable
        idx <- match(vars, as.character(res$Variable))
        for (i in seq_along(vars)) {
          j <- idx[i]
          if (is.na(j))
            next
          table$setRow(
            rowKey = private$.varKey(group, vars[i]),
            values = list(
              statistic = res$Statistic[j],
              pvalue = res$p.value[j],
              normality = ifelse(res$p.value[j] > 0.05, "Normal", "Not normal")
            )
          )
        }
      },

      # ---- Fill descriptives table ----
      .fillDescTable = function(res, vars, group) {
        table <- self$results$descTable
        # res rows correspond to vars in order
        for (i in seq_along(vars)) {
          if (i > nrow(res))
            next
          table$setRow(
            rowKey = private$.varKey(group, vars[i]),
            values = list(
              n = res$n[i],
              mean = res$Mean[i],
              sd = res$Std.Dev[i],
              median = res$Median[i],
              min = res$Min[i],
              max = res$Max[i],
              q25 = res$`25th`[i],
              q75 = res$`75th`[i],
              skew = res$Skew[i],
              kurtosis = res$Kurtosis[i]
            )
          )
        }
      },

      # ---- Fill outlier table (dynamic — count is data-driven) ----
      .fillOutlierTable = function(outliers, group) {
        table <- self$results$outlierTable
        if (nrow(outliers) == 0)
          return()
        for (i in seq_len(nrow(outliers))) {
          row <- list(
            obs = as.integer(outliers$Observation[i]),
            mahal = outliers$Mahalanobis.Distance[i]
          )
          if (!is.null(group))
            row$group <- group
          table$addRow(rowKey = paste0(group, "_out_", i), values = row)
        }
      },

      # ---- Helper: compute Mahalanobis Q-Q data ----
      .qqData = function(data, group = NULL) {
        n <- nrow(data)
        p <- ncol(data)
        S <- cov(data)
        xbar <- colMeans(data)
        d2 <- sort(mahalanobis(data, center = xbar, cov = S))
        chi2q <- qchisq(ppoints(n), df = p)
        df <- data.frame(theoretical = chi2q, observed = d2)
        if (!is.null(group))
          df$group <- group
        df
      },

      .themeValue = function(theme, component, index, fallback) {
        values <- NULL
        if (!is.null(theme) && !is.null(theme[[component]]))
          values <- as.character(unlist(theme[[component]], use.names = FALSE))
        values <- values[!is.na(values) & nzchar(values)]

        if (length(values) == 0)
          return(fallback)

        values[((index - 1L) %% length(values)) + 1L]
      },

      # ---- Multivariate Q-Q Plot ----
      .qqPlot = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        plotDF <- state$qqDF
        hasGroup <- state$hasGroup
        pointColor <- private$.themeValue(theme, "color", 1, "#4C78A8")
        lineColor <- private$.themeValue(theme, "color", 2, "#E45756")

        plot <- ggplot(plotDF, aes(x = theoretical, y = observed)) +
          geom_point(color = pointColor, size = 2) +
          geom_abline(
            intercept = 0,
            slope = 1,
            color = lineColor,
            linewidth = 1
          ) +
          labs(x = "Chi-Square Quantile", y = "Mahalanobis Distance")

        if (hasGroup)
          plot <- plot + facet_wrap(~ group)

        plot + ggtheme
      },

      # ---- Univariate Q-Q Plots ----
      .uniQQPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars
        pointColor <- private$.themeValue(theme, "color", 1, "#4C78A8")
        lineColor <- private$.themeValue(theme, "color", 2, "#E45756")

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        ggplot(longDF, aes(sample = value)) +
          stat_qq(color = pointColor, size = 1.5) +
          stat_qq_line(color = lineColor, linewidth = 1) +
          facet_wrap(~ variable, scales = "free") +
          labs(x = "Theoretical Quantiles", y = "Sample Quantiles") +
          ggtheme
      },

      # ---- Box Plots ----
      .boxPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars
        fillColor <- private$.themeValue(theme, "fill", 1, "#4C78A8")
        lineColor <- private$.themeValue(theme, "color", 1, "#2F4B7C")

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        ggplot(longDF, aes(x = variable, y = value)) +
          geom_boxplot(
            fill = fillColor,
            color = lineColor,
            alpha = 0.7
          ) +
          labs(x = "", y = "Value") +
          ggtheme
      },

      # ---- Histograms ----
      .histPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars
        fillColor <- private$.themeValue(theme, "fill", 1, "#4C78A8")
        lineColor <- private$.themeValue(theme, "color", 2, "#E45756")
        borderColor <- private$.themeValue(theme, "background", 1, "white")

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        curveList <- lapply(vars, function(v) {
          x <- data[[v]]
          m <- mean(x)
          s <- sd(x)
          xseq <- seq(min(x) - s, max(x) + s, length.out = 200)
          data.frame(
            variable = v,
            x = xseq,
            density = dnorm(xseq, mean = m, sd = s)
          )
        })
        curveDF <- do.call(rbind, curveList)
        curveDF$variable <- factor(curveDF$variable, levels = vars)

        ggplot(longDF, aes(x = value)) +
          geom_histogram(
            aes(y = after_stat(density)),
            fill = fillColor,
            color = borderColor,
            bins = 30
          ) +
          geom_line(
            data = curveDF,
            aes(x = x, y = density),
            color = lineColor,
            linewidth = 1
          ) +
          facet_wrap(~ variable, scales = "free") +
          labs(x = "Value", y = "Density") +
          ggtheme
      }
    )
  )
} else {
  NULL
}
