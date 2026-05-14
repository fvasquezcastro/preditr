summaryPlots <- function(results_df, job_name, output_folder){

  count_queries <- dplyr::n_distinct(results_df$query_num)
  
  count_errors <- results_df |>
    dplyr::filter(protospacer_seq != "Error" & (!is.na(error) & error != "")) |>
    nrow()
  
  count_not_found <- results_df |>
    dplyr::filter(protospacer_seq == "No guides found") |>
    nrow()
  
  count_all_guides <- results_df |>
    dplyr::filter(
      protospacer_seq != "No guides found" &
        (is.na(error) | error == "")
    ) |>
    nrow()
  
  count_clean_guides <- results_df |>
    dplyr::filter(
      protospacer_seq != "No guides found" &
        (is.na(error) | error == "") &
        (is.na(warnings) | warnings == "")
    ) |>
    nrow()
  
  count_warned_guides <- results_df |>
    dplyr::filter(
      protospacer_seq != "No guides found" &
        (is.na(error) | error == "") &
        (!is.na(warnings) & warnings != "")
    ) |>
    nrow()
  

  plot_df <- data.frame(
    Metric = c("Queries", "All Guides", "Clean Guides", "Warned Guides", "Not Found", "Errors"),
    Count = c(count_queries, count_all_guides, count_clean_guides, count_warned_guides, count_not_found, count_errors)
  )
    
    # Reorder factor for desired display order
    plot_df$Metric <- factor(plot_df$Metric, levels = plot_df$Metric)
    
    # Pretty bar plot
    p <- ggplot2::ggplot(plot_df, ggplot2::aes(
      x = forcats::fct_rev(factor(Metric, levels = c("Queries", "All Guides", "Clean Guides", "Warned Guides", "Not Found", "Errors"))),
      y = Count,
      fill = Metric
    )) +
      ggplot2::geom_col(width = 0.8, show.legend = FALSE) +
      ggplot2::geom_text(
        ggplot2::aes(label = Count), 
        hjust = -0.15, 
        size = 8, 
        fontface = "plain",
        family = "Inter"
      ) +
      ggplot2::scale_fill_manual(values = c(
        "Queries" = "#2c3e50",
        "All Guides" = "#4E7A97",
        "Clean Guides" = "#B7E4C7",
        "Warned Guides" = "#FFD6A5",
        "Not Found" = "#FFCDD2",
        "Errors" = "#E15759"
      )) +
      ggplot2::coord_flip(clip = "off") +
      ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.15))) +
      ggplot2::theme_minimal(
        base_size = 14, 
        base_family = "Inter" 
      ) +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::theme(
        panel.grid = ggplot2::element_blank(),
        axis.text.x = ggplot2::element_blank(),
        axis.ticks.x = ggplot2::element_blank(),
        axis.text.y = ggplot2::element_text(
          face = "plain", 
          size = 18, 
          margin = ggplot2::margin(r = 8)
        ),
        panel.spacing.y = ggplot2::unit(-1, "lines"), 
        plot.margin = ggplot2::margin(10, 20, 10, 20),
        plot.title = ggplot2::element_text(
          size = 18, 
          face = "plain",
          hjust = 0.5
        )
      )
    
    ggplot2::ggsave(file.path(output_folder, paste0(job_name, "_summary_plot.svg")), plot = p, width = 8, height = 5)
}