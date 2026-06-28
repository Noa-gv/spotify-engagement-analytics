--בניית פונקציות

/*******************************************************************************
שם השאילתה: שליפת 3 השירים המובילים ביותר מכל ז'אנר (Top 3 Songs Per Genre)
מטרה עסקית: זיהוי הלהיטים הגדולים ביותר בכל סגנון מוזיקלי לצורך המלצות או פילוח.

הסבר טכני על מבנה השאילתה (למה היא מעולה לתיק העבודות):
1. שימוש ב-CTE (Common Table Expression): 
   יצירת טבלה זמנית בזיכרון בשם 'RankedSongs'. זה מחליף שימוש בתתי-שאילתות 
   (Subqueries) ומציג קוד קריא, נקי ומקצועי יותר.
   
2. שימוש ב-Window Function (פונקציית חלון - ROW_NUMBER):
   - OVER (PARTITION BY F.GenreID): מחלק את כל הנתונים לקבוצות (חלונות) לפי הז'אנר.
     בכל פעם שהז'אנר מתחלף, ה-SQL מאפס את המונה ומתחיל לספור מ-1 מחדש.
   - ORDER BY F.popularity DESC: קובע שהדירוג בתוך כל ז'אנר יתבצע לפי מדד 
     הפופולריות, מהשיר הכי פופולרי (שיקבל את דירוג 1) ומטה.

3. סינון סופי בשאילתה הראשית:
   מתוך הטבלה הזמנית, אנחנו מסננים רק את השורות שבהן הדירוג ([Rank]) הוא 
   קטן או שווה ל-3, ובכך מקבלים בדיוק את ה"טופ 3" של כל ז'אנר.
*******************************************************************************/

WITH RankedSongs AS (
    SELECT 
        G.genre_name AS [Genre],
        T.track_name AS [Song Name],
        F.popularity AS [Popularity],
        ROW_NUMBER() OVER (PARTITION BY F.GenreID ORDER BY F.popularity DESC) AS [Rank]
    FROM Fact_Track_Metrics F
    JOIN Dim_Tracks T ON F.track_id = T.track_id
    JOIN Dim_Genres G ON F.GenreID = G.GenreID
)
SELECT 
    [Genre],
    [Rank],
    [Song Name],
    [Popularity]
FROM RankedSongs
WHERE [Rank] <= 3
ORDER BY [Genre] ASC, [Rank] ASC;

/*******************************************************************************
שם השאילתה: ניתוח מגמות פופולריות של אמנים (Artist Popularity Trend Analysis)
מטרה עסקית: הבנה האם אמן נמצא במגמת עלייה או ירידה בין שיר לשיר, וזיהוי "קפיצות" בהצלחה.

הסבר טכני על מבנה השאילתה (למה היא מעולה לתיק העבודות):
1. שימוש ב-CTE (Common Table Expression):
   מפיק רשימה של שירים מסודרים לפי אמן ואורך השיר (או כל סדר אחר שתבחרי), ומביא
   את מדד הפופולריות הנוכחי.

2. שימוש ב-Window Function מסוג LAG:
   - הפונקציה (LAG(F.popularity, 1 אומרת ל-SQL: "תביא לי את ערך הפופולריות של השורה הקודמת".
   - OVER (PARTITION BY T.ArtistID ORDER BY F.popularity ASC): החלוקה נעשית לפי אמן, 
     כך שכשהאמן מתחלף, ה-LAG לא יקח בטעות שיר של אמן אחר. הסדר נקבע מהשיר הפחות פופולרי להכי פופולרי.

3. חישוב ההפרש (Variance):
   בשאילתה הראשית אנחנו מחסירים בין הפופולריות של השיר הנוכחי לשיר הקודם, 
   וכך יודעים בדיוק בכמה נקודות השיר הזה מצליח יותר (מספר חיובי) או פחות (מספר שלילי) מהקודם.
*******************************************************************************/

WITH ArtistTrackHistory AS (
    SELECT 
        DA.artist_name AS [Artist],
        DT.track_name AS [Song Name],
        F.popularity AS [Current Popularity],
        -- שליפת הפופולריות של השיר הקודם של אותו אמן
        LAG(F.popularity, 1) OVER (PARTITION BY DT.ArtistID ORDER BY F.popularity ASC) AS [Previous Popularity]
    FROM Fact_Track_Metrics F
    JOIN Dim_Tracks DT ON F.track_id = DT.track_id
    JOIN Dim_Artists DA ON DT.ArtistID = DA.ArtistID
)
SELECT 
    [Artist],
    [Song Name],
    [Current Popularity],
    ISNULL([Previous Popularity], 0) AS [Previous Popularity],
    -- חישוב ההפרש בין השיר הנוכחי לקודם
    ([Current Popularity] - ISNULL([Previous Popularity], 0)) AS [Popularity Growth]
FROM ArtistTrackHistory
-- מציג רק אמנים שיש להם לפחות שיר קודם להשוואה (כדי שלא הכל יהיה 0)
WHERE [Previous Popularity] IS NOT NULL
ORDER BY [Artist] ASC, [Popularity Growth] DESC;

/*******************************************************************************
שם השאילתה: פילוח וניתוח שירים לפי מאפייני שמע (Audio Features Segmentation)
מטרה עסקית: הבנת העדפות המאזינים בכל ז'אנר – איזה סגנון שיר (אנרגטי, רגוע, דיבורי) משיג את הפופולריות הגבוהה ביותר.

הסבר טכני על מבנה השאילתה (למה היא מעולה לתיק העבודות):
1. שימוש ב-CTEs מרובים (שרשור טבלאות זמניות):
   - ה-CTE הראשון ('SongSegmentation') משתמש בביטויי CASE WHEN כדי לסווג כל שיר 
     על בסיס המדדים הטכנולוגיים שלו (למשל, שיר עם מעל 0.7 באנרגיה וקצביות נחשב 'High Energy/Danceable').
   - ה-CTE השני ('GenreAudioStats') לוקח את המידע ומחשב את הממוצעים והסיכומים.

2. שימוש בפונקציות אגרגציה (Aggregation) וסינון מתקדם:
   השאילתה הראשית מחברת את הכל כדי לתת מבט על, ומציגה רק שילובים משמעותיים 
   (למשל, ז'אנרים שיש בהם מספיק שירים מאותה קטגוריה) כדי למנוע עיוות של הנתונים.
*******************************************************************************/

WITH SongSegmentation AS (
    SELECT 
        track_id,
        GenreID,
        popularity,
        -- סיווג השיר לקבוצות איכותיות על בסיס המדדים הרציפים שלו
        CASE 
            WHEN energy > 0.7 AND danceability > 0.7 THEN 'High Energy & Danceable'
            WHEN acousticness > 0.7 THEN 'Acoustic & Calm'
            WHEN speechiness > 0.6 THEN 'Speech-Heavy / Podcast'
            ELSE 'Balanced / Standard Pop'
        END AS [Song_Vibe]
    FROM Fact_Track_Metrics
),
GenreAudioStats AS (
    SELECT 
        G.genre_name AS [Genre],
        S.[Song_Vibe],
        AVG(S.popularity) AS [Avg_Popularity],
        COUNT(S.track_id) AS [Total_Songs],
        -- שימוש ב-Window Function כדי לראות את סך השירים בז'אנר כולו
        SUM(COUNT(S.track_id)) OVER(PARTITION BY G.genre_name) AS [Total_Genre_Songs]
    FROM SongSegmentation S
    JOIN Dim_Genres G ON S.GenreID = G.GenreID
    GROUP BY G.genre_name, S.[Song_Vibe]
)
SELECT 
    [Genre],
    [Song_Vibe],
    [Avg_Popularity],
    [Total_Songs],
    -- חישוב אחוז השירים מאותו ה-Vibe מתוך כלל הז'אנר
    CAST((CAST([Total_Songs] AS FLOAT) / [Total_Genre_Songs]) * 100 AS DECIMAL(5,2)) AS [Percentage_Of_Genre]
FROM GenreAudioStats
-- סינון של קבוצות קטנות מדי כדי לקבל תובנות מובהקות
WHERE [Total_Songs] > 10
ORDER BY [Genre] ASC, [Avg_Popularity] DESC;