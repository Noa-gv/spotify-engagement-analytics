--יצירת טבלאות 
-- =======================================================
-- 1. יצירת טבלת אומנים (Dim_Artists) והכנסת נתונים
-- =======================================================
CREATE TABLE Dim_Artists (
    ArtistID INT IDENTITY(1,1) PRIMARY KEY,
    artist_name NVARCHAR(255) NOT NULL
);

INSERT INTO Dim_Artists (artist_name)
SELECT DISTINCT artist_name
FROM SpotifyFeatures
WHERE artist_name IS NOT NULL AND artist_name <> '';

-- =======================================================
-- 2. יצירת טבלת ז'אנרים (Dim_Genres) והכנסת נתונים
-- =======================================================
CREATE TABLE Dim_Genres (
    GenreID INT IDENTITY(1,1) PRIMARY KEY,
    genre_name VARCHAR(100) NOT NULL
);

INSERT INTO Dim_Genres (genre_name)
SELECT DISTINCT genre
FROM SpotifyFeatures
WHERE genre IS NOT NULL;

-- =======================================================
-- 3. יצירת טבלת שירים מעודכנת (Dim_Tracks) כולל ז'אנר ואמן
-- =======================================================
CREATE TABLE Dim_Tracks (
    track_id VARCHAR(50) PRIMARY KEY, 
    track_name NVARCHAR(500),
    ArtistID INT FOREIGN KEY REFERENCES Dim_Artists(ArtistID),                     
    GenreID INT FOREIGN KEY REFERENCES Dim_Genres(GenreID), -- כאן הגדרת ה-GenreID בטבלת השירים!
    duration_ms INT,
    [key] VARCHAR(10),                 
    mode VARCHAR(10),
    time_signature VARCHAR(10)
);

-- הכנסת נתונים ללא כפילויות: בוחרים לכל שיר את המופע הכי פופולרי שלו
INSERT INTO Dim_Tracks (track_id, track_name, ArtistID, GenreID, duration_ms, [key], mode, time_signature)
SELECT track_id, track_name, ArtistID, GenreID, duration_ms, [key], mode, time_signature
FROM (
    SELECT 
        SF.track_id, 
        SF.track_name, 
        DA.ArtistID,
        DG.GenreID, 
        SF.duration_ms, 
        SF.[key], 
        SF.mode, 
        SF.time_signature,
        ROW_NUMBER() OVER (PARTITION BY SF.track_id ORDER BY SF.popularity DESC) as rn
    FROM SpotifyFeatures SF
    LEFT JOIN Dim_Artists DA ON SF.artist_name = DA.artist_name
    LEFT JOIN Dim_Genres DG ON SF.genre = DG.genre_name
) as CleanedData
WHERE rn = 1;

-- =======================================================
-- 4. יצירת טבלת העובדות (Fact_Track_Metrics)
-- =======================================================
CREATE TABLE Fact_Track_Metrics (
    MetricID INT IDENTITY(1,1) PRIMARY KEY,
    track_id VARCHAR(50) FOREIGN KEY REFERENCES Dim_Tracks(track_id),
    popularity INT,
    acousticness FLOAT,
    danceability FLOAT,
    energy FLOAT,
    instrumentalness FLOAT,
    liveness FLOAT,
    loudness FLOAT,
    speechiness FLOAT,
    tempo FLOAT,
    valence FLOAT
);

-- הכנסת הנתונים לטבלת העובדות על בסיס השירים הייחודיים שבחרנו
INSERT INTO Fact_Track_Metrics (
    track_id, popularity, acousticness, danceability, 
    energy, instrumentalness, liveness, loudness, speechiness, tempo, valence
)
SELECT 
    SF.track_id,
    SF.popularity,
    SF.acousticness,
    SF.danceability,
    SF.energy,
    SF.instrumentalness,
    SF.liveness,
    SF.loudness,
    SF.speechiness,
    SF.tempo,
    SF.valence
FROM SpotifyFeatures SF
JOIN Dim_Tracks DT ON SF.track_id = DT.track_id 
JOIN Dim_Genres DG ON DT.GenreID = DG.GenreID AND SF.genre = DG.genre_name; 

-- =======================================================
-- 5. בדיקה קלה שהכל עלה יפה
-- =======================================================
SELECT TOP 5 * FROM Dim_Tracks;
SELECT TOP 5 * FROM Fact_Track_Metrics;