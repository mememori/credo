defmodule Credo.CLI.Output.IssuesGroupedByCategory do
  alias Credo.CLI.Filter
  alias Credo.CLI.Output
  alias Credo.CLI.Output.IssueHelper
  alias Credo.CLI.Output.UI
  alias Credo.CLI.Output.Summary
  alias Credo.CLI.Sorter
  alias Credo.Config

  @category_starting_order [:design, :readability, :refactor]
  @category_ending_order [:warning, :consistency, :custom, :unknown]
  @category_colors [
    design: :olive,
    readability: :blue,
    refactor: :yellow,
    warning: :red,
    consistency: :cyan,
  ]
  @category_titles [
    design: "Software Design",
    readability: "Code Readability",
    refactor: "Refactoring opportunities",
    warning: "Warnings - please take a look",
    consistency: "Consistency",
  ]
  @many_source_files 60
  @per_category 5
  @valid_formats ~w(flycheck oneline)

  @doc "Called before the analysis is run."
  def print_before_info(_source_files, %Config{format: format}) when format in @valid_formats do
    :ok
  end
  def print_before_info(source_files, config) do
    case Enum.count(source_files) do
      0 -> UI.puts "No files found!"
      1 -> UI.puts "Checking 1 source file ..."
      count -> UI.puts "Checking #{count} source files#{checking_suffix(count)} ..."
    end

    Output.print_skipped_checks(config)
  end

  defp checking_suffix(count) do
    if count > @many_source_files do
      " (this might take a while)"
    else
      ""
    end
  end

  @doc "Called after the analysis has run."
  def print_after_info(source_files, config, time_load, time_run) do
    term_width = Output.term_columns

    issues = source_files |> Enum.flat_map(&(&1.issues))
    shown_issues =
      issues
      |> Filter.important(config)
      |> Filter.valid_issues(config)

    categories =
      shown_issues
      |> Enum.map(&(&1.category))
      |> Enum.uniq

    issue_map =
      categories
      |> Enum.map(fn(category) ->
          {category, shown_issues |> Enum.filter(&(&1.category == category))}
        end)
      |> Enum.into(%{})

    source_file_map =
      source_files
      |> Enum.map(&({&1.filename, &1}))
      |> Enum.into(%{})

    categories
    |> Sorter.ensure(@category_starting_order, @category_ending_order)
    |> Enum.each(fn(category) ->
        print_issues_for_category(category, issue_map[category], source_file_map, config, term_width)
      end)

    source_files
    |> Summary.print(config, time_load, time_run)
  end

  defp print_issues_for_category(_category, nil, _source_file_map, _config, _term_width) do
    nil
  end
  defp print_issues_for_category(_category, issues, source_file_map, %Config{format: format} = config, term_width)
        when not is_nil(format) and format in @valid_formats do
    print_issues(issues, source_file_map, config, term_width)
  end
  defp print_issues_for_category(_category, issues, source_file_map, %Config{format: "oneline"} = config, term_width) do
    print_issues(issues, source_file_map, config, term_width)
  end
  defp print_issues_for_category(category, issues, source_file_map, config, term_width) do
    color = @category_colors[category] || :magenta
    title = @category_titles[category] || "Category: #{category}"

    UI.puts

    [
      :bright, "#{color}_background" |> String.to_atom, color, " ",
        Output.foreground_color(color), :normal,
      " #{title}" |> String.ljust(term_width - 1),
    ]
    |> UI.puts

    color
    |> UI.edge
    |> UI.puts

    print_issues(issues, source_file_map, config, term_width)

    if Enum.count(issues) > per_category(config) do
      not_shown = Enum.count(issues) - per_category(config)

      [UI.edge(color), :faint, " ...  (#{not_shown} more, use `-a` to show them)"]
      |> UI.puts
    end
  end

  defp print_issues(issues, source_file_map, config, term_width) do
    count = per_category(config)

    issues
    |> Enum.sort_by(fn(issue) ->
        {issue.priority, issue.severity, issue.filename, issue.line_no}
      end)
    |> Enum.reverse
    |> Enum.take(count)
    |> IssueHelper.print_issues(source_file_map, config, term_width)
  end

  def per_category(%Config{all: true}), do: 1_000_000
  def per_category(%Config{all: false}), do: @per_category

end
