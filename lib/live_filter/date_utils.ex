defmodule LiveFilter.DateUtils do
  @moduledoc """
  Date utility functions for LiveFilter.
  Handles date range calculations for presets and custom ranges.
  """

  @doc """
  Converts a date preset string or date range tuple to a proper date range.
  Supports optional timestamp_type parameter for converting dates to timestamps.
  """
  def parse_date_range(value, timestamp_type \\ :date)

  def parse_date_range(nil, _timestamp_type), do: nil

  def parse_date_range({start_date, end_date}, timestamp_type) when is_struct(start_date, Date) do
    convert_range_to_type({start_date, end_date}, timestamp_type)
  end

  def parse_date_range({start_dt, end_dt}, timestamp_type) when is_struct(start_dt, DateTime) do
    convert_range_to_type({start_dt, end_dt}, timestamp_type)
  end

  def parse_date_range({start_ndt, end_ndt}, timestamp_type)
      when is_struct(start_ndt, NaiveDateTime) do
    convert_range_to_type({start_ndt, end_ndt}, timestamp_type)
  end

  def parse_date_range(preset, timestamp_type) when is_binary(preset) do
    today = Date.utc_today()

    case preset do
      "today" ->
        convert_range_to_type({today, today}, timestamp_type)

      "tomorrow" ->
        tomorrow = Date.add(today, 1)
        convert_range_to_type({tomorrow, tomorrow}, timestamp_type)

      "yesterday" ->
        yesterday = Date.add(today, -1)
        convert_range_to_type({yesterday, yesterday}, timestamp_type)

      "last_7_days" ->
        convert_range_to_type({Date.add(today, -6), today}, timestamp_type)

      "next_7_days" ->
        convert_range_to_type({today, Date.add(today, 6)}, timestamp_type)

      "last_30_days" ->
        convert_range_to_type({Date.add(today, -29), today}, timestamp_type)

      "next_30_days" ->
        convert_range_to_type({today, Date.add(today, 29)}, timestamp_type)

      "this_month" ->
        first_day = %{today | day: 1}
        last_day = %{today | day: Date.days_in_month(today)}
        convert_range_to_type({first_day, last_day}, timestamp_type)

      "last_month" ->
        last_month = Date.add(today, -Date.days_in_month(Date.add(today, -1)))
        first_day = %{last_month | day: 1}
        last_day = %{last_month | day: Date.days_in_month(last_month)}
        convert_range_to_type({first_day, last_day}, timestamp_type)

      "this_year" ->
        convert_range_to_type(
          {%{today | month: 1, day: 1}, %{today | month: 12, day: 31}},
          timestamp_type
        )

      _ ->
        nil
    end
  end

  def parse_date_range(_, _), do: nil

  @doc """
  Converts a date range to the specified timestamp type.
  """
  def convert_range_to_type({start_date, end_date}, type) do
    {convert_to_type(start_date, type, :start), convert_to_type(end_date, type, :end)}
  end

  @doc """
  Converts a single date/datetime to the specified type.
  For ranges, use :start for beginning of day and :end for end of day.
  """
  def convert_to_type(date, :date, _position) when is_struct(date, Date), do: date

  def convert_to_type(date, :datetime, position) when is_struct(date, Date) do
    convert_to_type(date, :utc_datetime, position)
  end

  def convert_to_type(date, :utc_datetime, position) when is_struct(date, Date) do
    time =
      case position do
        :start -> ~T[00:00:00]
        :end -> ~T[23:59:59]
        _ -> ~T[00:00:00]
      end

    DateTime.new!(date, time, "Etc/UTC")
  end

  def convert_to_type(date, :naive_datetime, position) when is_struct(date, Date) do
    time =
      case position do
        :start -> ~T[00:00:00]
        :end -> ~T[23:59:59]
        _ -> ~T[00:00:00]
      end

    NaiveDateTime.new!(date, time)
  end

  # DateTime conversions
  def convert_to_type(datetime, :date, _position) when is_struct(datetime, DateTime) do
    DateTime.to_date(datetime)
  end

  def convert_to_type(datetime, :datetime, _position) when is_struct(datetime, DateTime),
    do: datetime

  def convert_to_type(datetime, :utc_datetime, _position) when is_struct(datetime, DateTime),
    do: datetime

  def convert_to_type(datetime, :naive_datetime, _position) when is_struct(datetime, DateTime) do
    DateTime.to_naive(datetime)
  end

  # NaiveDateTime conversions
  def convert_to_type(ndt, :date, _position) when is_struct(ndt, NaiveDateTime) do
    NaiveDateTime.to_date(ndt)
  end

  def convert_to_type(ndt, :datetime, _position) when is_struct(ndt, NaiveDateTime) do
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  def convert_to_type(ndt, :utc_datetime, _position) when is_struct(ndt, NaiveDateTime) do
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  def convert_to_type(ndt, :naive_datetime, _position) when is_struct(ndt, NaiveDateTime), do: ndt
end
