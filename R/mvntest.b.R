
#' @importFrom jmvcore .
#' @importFrom stats mahalanobis qchisq ppoints cov qqnorm qqline dnorm sd
#' @importFrom graphics par abline hist curve boxplot plot

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

        vars <- self$options$vars
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

        # Store prepared data as state for plot render functions
        # (self$data is not available when render functions are called)
        plotData <- as.data.frame(data[, vars, drop = FALSE])
        self$results$qqPlot$setState(plotData)
        self$results$uniPlots$setState(plotData)
        self$results$boxPlots$setState(plotData)
        self$results$histPlots$setState(plotData)
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

      # ---- Multivariate Q-Q Plot ----
      .qqPlot = function(image, ggtheme, theme, ...) {
        if (is.null(image$state))
          return(FALSE)

        data <- image$state
        numData <- as.matrix(data)

        n <- nrow(numData)
        p <- ncol(numData)
        if (n < 3 || p < 2)
          return(FALSE)

        S <- cov(numData)
        xbar <- colMeans(numData)
        d2 <- mahalanobis(numData, center = xbar, cov = S)
        d2 <- sort(d2)
        chi2q <- qchisq(ppoints(n), df = p)

        plot(chi2q, d2,
             main = "Multivariate Q-Q Plot",
             xlab = "Chi-Square Quantile",
             ylab = "Mahalanobis Distance",
             pch = 19, col = "steelblue")
        abline(a = 0, b = 1, col = "red", lwd = 2)
        TRUE
      },

      # ---- Univariate Q-Q Plots ----
      .uniQQPlots = function(image, ggtheme, theme, ...) {
        if (is.null(image$state))
          return(FALSE)

        data <- image$state
        vars <- colnames(data)
        if (length(vars) < 2)
          return(FALSE)

        nv <- length(vars)
        nc <- min(nv, 3)
        nr <- ceiling(nv / nc)
        par(mfrow = c(nr, nc))

        for (v in vars) {
          qqnorm(data[[v]], main = v, pch = 19, col = "steelblue")
          qqline(data[[v]], col = "red", lwd = 2)
        }

        par(mfrow = c(1, 1))
        TRUE
      },

      # ---- Box Plots ----
      .boxPlots = function(image, ggtheme, theme, ...) {
        if (is.null(image$state))
          return(FALSE)

        data <- image$state
        if (ncol(data) < 2)
          return(FALSE)

        boxplot(data, col = "steelblue", main = "Box Plots",
                las = 2, border = "darkblue")
        TRUE
      },

      # ---- Histograms ----
      .histPlots = function(image, ggtheme, theme, ...) {
        if (is.null(image$state))
          return(FALSE)

        data <- image$state
        vars <- colnames(data)
        if (length(vars) < 2)
          return(FALSE)

        nv <- length(vars)
        nc <- min(nv, 3)
        nr <- ceiling(nv / nc)
        par(mfrow = c(nr, nc))

        for (v in vars) {
          vals <- data[[v]]
          m <- mean(vals, na.rm = TRUE)
          s <- sd(vals, na.rm = TRUE)
          hist(vals, main = v, xlab = v, col = "steelblue",
               border = "white", freq = FALSE, breaks = "Sturges")
          if (!is.na(s) && s > 0) {
            curve(dnorm(x, mean = m, sd = s),
                  add = TRUE, col = "red", lwd = 2)
          }
        }

        par(mfrow = c(1, 1))
        TRUE
      }
    )
  )
} else {
  NULL
}
