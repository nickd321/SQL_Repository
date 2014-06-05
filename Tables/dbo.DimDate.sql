CREATE TABLE [dbo].[DimDate]
(
[DimDateID] [int] NOT NULL,
[FullDate] [datetime] NOT NULL,
[Day] [tinyint] NOT NULL,
[DaySuffix] [varchar] (4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DayOfWeek] [varchar] (9) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DayOfWeekNumber] [int] NOT NULL,
[DayOfWeekInMonth] [tinyint] NOT NULL,
[DayOfYearNumber] [int] NOT NULL,
[RelativeDays] [int] NOT NULL,
[WeekOfYearNumber] [tinyint] NOT NULL,
[WeekOfMonthNumber] [tinyint] NOT NULL,
[RelativeWeeks] [int] NOT NULL,
[CalendarMonthNumber] [tinyint] NOT NULL,
[CalendarMonthName] [varchar] (9) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RelativeMonths] [int] NOT NULL,
[CalendarQuarterNumber] [tinyint] NOT NULL,
[CalendarQuarterName] [varchar] (6) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RelativeQuarters] [int] NOT NULL,
[CalendarYearNumber] [int] NOT NULL,
[RelativeYears] [int] NOT NULL,
[StandardDate] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[WeekDayFlag] [bit] NOT NULL,
[HolidayFlag] [bit] NOT NULL,
[OpenFlag] [bit] NOT NULL,
[FirstDayOfCalendarMonthFlag] [bit] NOT NULL,
[LastDayOfCalendarMonthFlag] [bit] NOT NULL,
[HolidayText] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DimDate] ADD CONSTRAINT [PK_DimDate] PRIMARY KEY CLUSTERED  ([DimDateID]) WITH (FILLFACTOR=90) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_DimDate_FullDate] ON [dbo].[DimDate] ([FullDate]) ON [PRIMARY]
GO
