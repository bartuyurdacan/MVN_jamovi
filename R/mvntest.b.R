
#' @importFrom jmvcore .
#' @importFrom stats mahalanobis qchisq cov dnorm sd ppoints
#' @importFrom ggplot2 ggplot aes geom_point geom_abline geom_line labs
#'   facet_wrap stat_qq stat_qq_line geom_histogram after_stat geom_boxplot

mvntestClass <- if (requireNamespace("jmvcore", quietly = TRUE)) {
  R6::R6Class(
    "mvntestClass",
    inherit = mvntestBase,
    private = list(

      # ---- Main analysis ----
      .run = function() {

        if (is.null(self$options$vars) || length(self$options$vars) < 2) {
          return()
        }

        data <- private$.prepareData()
        if (is.null(data))
          return()

        hasGroup <- !is.null(self$options$group)

        if (hasGroup) {
          groupVar <- self$options$group
          groups <- levels(factor(self$data[[groupVar]]))
          splitData <- split(
            data[, !(colnames(data) %in% groupVar), drop = FALSE],
            data[[groupVar]]
          )
          private$.runGrouped(splitData, groups)
        } else {
          private$.runSingle(data)
        }

        # Store plot data in image state for deferred rendering
        vars <- self$options$vars
        plotData <- as.data.frame(data[, vars, drop = FALSE])

        # Multivariate Q-Q data
        if (hasGroup) {
          groupVar <- self$options$group
          splitNum <- split(
            data[, !(colnames(data) %in% groupVar), drop = FALSE],
            data[[groupVar]]
          )
          qqDFs <- lapply(names(splitNum), function(g) {
            grpData <- as.matrix(splitNum[[g]])
            private$.qqData(grpData, group = g)
          })
          qqDF <- do.call(rbind, qqDFs)
        } else {
          numData <- as.matrix(plotData)
          qqDF <- private$.qqData(numData)
        }

        self$results$qqPlot$setState(list(
          qqDF = qqDF,
          hasGroup = hasGroup
        ))

        self$results$uniPlots$setState(list(
          data = plotData,
          vars = vars
        ))

        self$results$boxPlots$setState(list(
          data = plotData,
          vars = vars
        ))

        self$results$histPlots$setState(list(
          data = plotData,
          vars = vars
        ))
      },

      # ---- Prepare data ----
      .prepareData = function() {
        vars <- self$options$vars
        groupVar <- self$options$group

        cols <- vars
        if (!is.null(groupVar))
          cols <- c(cols, groupVar)

        data <- jmvcore::select(self$data, cols)

        # Convert numeric columns
        for (v in vars) {
          data[[v]] <- jmvcore::toNumeric(data[[v]])
        }

        # Handle missing data
        if (self$options$impute == "none") {
          data <- data[complete.cases(data), ]
        } else {
          numData <- data[, vars, drop = FALSE]
          numData <- impute_missing(numData, method = self$options$impute)
          data[, vars] <- numData
        }

        if (nrow(data) < 3)
          return(NULL)

        # Scaling
        if (self$options$scale) {
          data[, vars] <- scale(data[, vars])
        }

        # Marginal transforms
        if (self$options$transform == "log") {
          data[, vars] <- apply(data[, vars, drop = FALSE], 2, log)
        } else if (self$options$transform == "sqrt") {
          data[, vars] <- apply(data[, vars, drop = FALSE], 2, sqrt)
        } else if (self$options$transform == "square") {
          data[, vars] <- apply(data[, vars, drop = FALSE], 2, function(x) x^2)
        }

        # Power transformation
        if (self$options$powerFamily != "none") {
          numData <- data[, vars, drop = FALSE]
          result <- power_transform(numData,
                                    family = self$options$powerFamily,
                                    type = "optimal")
          data[, vars] <- result$data
        }

        data
      },

      # ---- Single group ----
      .runSingle = function(data) {
        vars <- self$options$vars
        numData <- data[, vars, drop = FALSE]

        # MVN test
        mvnRes <- private$.doMVNTest(numData)
        private$.fillMVNTable(mvnRes, group = NULL)

        # Univariate test
        uniRes <- test_univariate_normality(numData, test = self$options$univariateTest)
        private$.fillUniTable(uniRes, group = NULL)

        # Descriptives
        if (self$options$showDescriptives) {
          descRes <- descriptives(numData)
          private$.fillDescTable(descRes, vars, group = NULL)
        }

        # Outliers
        if (self$options$outlierMethod != "none") {
          outlierRes <- mv_outlier(
            numData,
            qqplot = FALSE,
            alpha = self$options$outlierAlpha,
            method = self$options$outlierMethod
          )
          outliers <- outlierRes$outlier[outlierRes$outlier$Outlier == "TRUE", ]
          private$.fillOutlierTable(outliers, group = NULL)
        }
      },

      # ---- Grouped analysis ----
      .runGrouped = function(splitData, groups) {
        for (g in groups) {
          grpData <- splitData[[g]]
          if (nrow(grpData) < 3)
            next

          # MVN test
          mvnRes <- private$.doMVNTest(grpData)
          private$.fillMVNTable(mvnRes, group = g)

          # Univariate test
          uniRes <- test_univariate_normality(grpData, test = self$options$univariateTest)
          private$.fillUniTable(uniRes, group = g)

          # Descriptives
          if (self$options$showDescriptives) {
            descRes <- descriptives(grpData)
            private$.fillDescTable(descRes, self$options$vars, group = g)
          }

          # Outliers
          if (self$options$outlierMethod != "none") {
            outlierRes <- mv_outlier(
              grpData,
              qqplot = FALSE,
              alpha = self$options$outlierAlpha,
              method = self$options$outlierMethod
            )
            outliers <- outlierRes$outlier[outlierRes$outlier$Outlier == "TRUE", ]
            private$.fillOutlierTable(outliers, group = g)
          }
        }
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

      # ---- Fill MVN table ----
      .fillMVNTable = function(res, group) {
        table <- self$results$mvnTable
        for (i in seq_len(nrow(res))) {
          row <- list(
            test = as.character(res$Test[i]),
            statistic = res$Statistic[i],
            pvalue = res$p.value[i],
            result = ifelse(res$p.value[i] > 0.05, "Normal", "Not normal")
          )
          if (!is.null(group))
            row$group <- group
          table$addRow(rowKey = paste0(group, "_", i), values = row)
        }
      },

      # ---- Fill univariate table ----
      .fillUniTable = function(res, group) {
        table <- self$results$uniTable
        for (i in seq_len(nrow(res))) {
          row <- list(
            test = as.character(res$Test[i]),
            var = as.character(res$Variable[i]),
            statistic = res$Statistic[i],
            pvalue = res$p.value[i],
            normality = ifelse(res$p.value[i] > 0.05, "Normal", "Not normal")
          )
          if (!is.null(group))
            row$group <- group
          table$addRow(rowKey = paste0(group, "_uni_", i), values = row)
        }
      },

      # ---- Fill descriptives table ----
      .fillDescTable = function(res, vars, group) {
        table <- self$results$descTable
        for (i in seq_len(nrow(res))) {
          row <- list(
            var = vars[i],
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
          if (!is.null(group))
            row$group <- group
          table$addRow(rowKey = paste0(group, "_desc_", i), values = row)
        }
      },

      # ---- Fill outlier table ----
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

      # ---- Multivariate Q-Q Plot ----
      .qqPlot = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        plotDF <- state$qqDF
        hasGroup <- state$hasGroup

        if (hasGroup) {
          p <- ggplot(plotDF, aes(x = theoretical, y = observed)) +
            geom_point(color = "steelblue", size = 2) +
            geom_abline(intercept = 0, slope = 1, color = "red", linewidth = 1) +
            facet_wrap(~ group) +
            labs(x = "Chi-Square Quantile", y = "Mahalanobis Distance") +
            ggtheme
        } else {
          p <- ggplot(plotDF, aes(x = theoretical, y = observed)) +
            geom_point(color = "steelblue", size = 2) +
            geom_abline(intercept = 0, slope = 1, color = "red", linewidth = 1) +
            labs(title = "Multivariate Q-Q Plot",
                 x = "Chi-Square Quantile", y = "Mahalanobis Distance") +
            ggtheme
        }

        p
      },

      # ---- Univariate Q-Q Plots ----
      .uniQQPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        p <- ggplot(longDF, aes(sample = value)) +
          stat_qq(color = "steelblue", size = 1.5) +
          stat_qq_line(color = "red", linewidth = 1) +
          facet_wrap(~ variable, scales = "free") +
          labs(x = "Theoretical Quantiles", y = "Sample Quantiles") +
          ggtheme

        p
      },

      # ---- Box Plots ----
      .boxPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        p <- ggplot(longDF, aes(x = variable, y = value)) +
          geom_boxplot(fill = "steelblue", color = "darkblue", alpha = 0.7) +
          labs(title = "Box Plots", x = "", y = "Value") +
          ggtheme

        p
      },

      # ---- Histograms ----
      .histPlots = function(image, ggtheme, theme, ...) {
        state <- image$state
        if (is.null(state))
          return()

        data <- state$data
        vars <- state$vars

        longList <- lapply(vars, function(v) {
          data.frame(variable = v, value = data[[v]])
        })
        longDF <- do.call(rbind, longList)
        longDF$variable <- factor(longDF$variable, levels = vars)

        # Pre-compute normal density curves per variable
        curveList <- lapply(vars, function(v) {
          x <- data[[v]]
          m <- mean(x)
          s <- sd(x)
          xseq <- seq(min(x) - s, max(x) + s, length.out = 200)
          data.frame(variable = v, x = xseq, density = dnorm(xseq, mean = m, sd = s))
        })
        curveDF <- do.call(rbind, curveList)
        curveDF$variable <- factor(curveDF$variable, levels = vars)

        p <- ggplot(longDF, aes(x = value)) +
          geom_histogram(aes(y = after_stat(density)),
                         fill = "steelblue", color = "white", bins = 30) +
          geom_line(data = curveDF, aes(x = x, y = density),
                    color = "red", linewidth = 1) +
          facet_wrap(~ variable, scales = "free") +
          labs(x = "Value", y = "Density") +
          ggtheme

        p
      }
    )
  )
} else {
  NULL
}
