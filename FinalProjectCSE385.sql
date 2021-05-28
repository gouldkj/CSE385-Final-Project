USE [master]
GO

DROP DATABASE IF EXISTS[MovieReviews]
GO

CREATE DATABASE MovieReviews
GO

USE MovieReviews
GO


------------------------------------------------------------------- Tables

CREATE TABLE tblUsers(
	userId		INT			PRIMARY KEY		NOT NULL,
	userName	VARCHAR(20)					NOT NULL,
	age			INT							NOT NULL,
	isCritic	BIT							NOT NULL,
	firstName	VARCHAR(50)					NOT NULL,
	lastName	VARCHAR(50)					NOT NULL,
	email		VARCHAR(50)					NOT NULL,
	[password]	VARCHAR(50)					NOT NULL
)
GO

CREATE TABLE tblMovies(
	movieId			INT			PRIMARY KEY		NOT NULL,
	movieName		VARCHAR(50)					NOT NULL,
	yearReleased	INT							NOT NULL,
	rating			VARCHAR(10)					
)
GO

CREATE TABLE tblPosts(
	postId		INT			PRIMARY KEY		NOT NULL,
	userId		INT							NOT NULL,
	movieId		INT							NOT NULL,
	score		FLOAT						NOT NULL,
	review		VARCHAR(500)				NOT NULL,
	datePosted	DATETIME					NOT NULL,
	isDeleted	BIT							NOT NULL
)
GO

CREATE TABLE tblDirectors(
	directorId	INT							NOT NULL,
	movieId		INT							NOT NULL,
	PRIMARY KEY(directorId,movieId)
)
GO

------------------------------------------------------------------- Bulk Insert


INSERT INTO tblUsers(userId,userName, age, 
						 isCritic, firstName,
						 lastName, email,
						 password)
				VALUES  (1,'bobby52',15,
							0,'Bobby','Montesano',
							'bobby52@gmail.com','Password1234'),
						(2,'Skull67',25,
							0,'Sarah','Sampson',
							'ssampson@gmail.com','Puppy531'),
						(3,'SunSidney',19,
							0,'Sidney','Hutson',
							'sidneyh@comcast.net','mickey52!'),
						(4,'Budy_Paco',19,
							1,'Patrick','Larmon',
							'larmonpj@gmail.com','Pep$i6060'),
						(5,'SimpsonLover',48,
							1,'Carl','Pepper',
							'peppercarl@yahoo.net','Homer1971'),
						(6,'FrzAnna',32,
							0,'Jennifer','Lee',
							'jenlee@gmail.com','l3titgo'),
						(7,'Buckman',33,
							0,'Chris','Buck',
							'chrisbuck@gmail.com','snowman'),
						(8,'Knives27',46,
							1,'Rian','Johnson',
							'rianjohnson@gmail.com','m0vi3s'),
						(9,'TheKing',24,
							0,'Melina','Matsoukas',
							'melinama@gmail.com','$paSsw0rd!');

GO

INSERT INTO tblMovies(movieId, movieName, yearReleased, rating)
				VALUES  (1,'Frozen 2',2019,'PG'),
						(2,'Knives Out',2019,'PG13'),
						(3,'Queen & Slim',2019,'R'),
						(4,'Ford v Ferrari',2019,'PG13'),
						(5,'A Beautiful Day in the Neighborhood',2019,'PG'),
						(6,'Dark Waters',2019,'PG13'),
						(7,'Midway',2019,'PG13'),
						(8,'Joker',2019,'R');

GO


INSERT INTO tblPosts(postId,userId,movieId,score,review,datePosted,isDeleted)
				VALUES	(1,1,8,8,'This was a very good movie.','11/21/2019',0),
						(2,1,7,7,'This movie was alright.','12/05/2019',0),
						(3,1,5,8,'I really liked this movie.','11/20/2019',0),
						(4,4,2,9,'I loved this movie, best of 2019.','12/01/2019',0),
						(5,3,6,5,'I was let down by this movie, disapointing.','11/18/2019',0),
						(6,3,4,6,'I was not rrazy about this movie.','11/30/2019',1),
						(7,1,3,7,'This was a good movie, would recommend.','11/28/2019',0),
						(8,4,1,7,'Great family film!','12/02/2019',0),
						(9,5,1,8,'Really liked this film, great music.','11/19/2019',1),
						(10,4,8,9,'Fantastic film, instant classic.','11/21/2019',0);

GO

INSERT INTO tblDirectors(directorId,movieId)
				VALUES	(6,1),
						(6,5),
						(7,1),
						(8,2),
						(9,3);

GO

------------------------------------------------------------------- Stored Procedures


CREATE PROCEDURE spAvgCriticScore
AS
	SELECT  DISTINCT m.movieId,
			m.movieName,
			[avgCriticScore] = (
									SELECT AVG(p.score) 
									FROM tblPosts p 
										JOIN tblUsers u ON (u.userId = p.userId)
									WHERE (p.movieId = m.movieId) AND (u.isCritic = 1)
							   )
	FROM tblPosts p
		JOIN tblUsers u ON (u.userId = p.userId)
		JOIN tblMovies m ON (p.movieId = m.movieId)
	WHERE u.isCritic = 1
	GROUP BY p.score,p.userId, u.userId, u.isCritic, m.movieId, m.movieName
	ORDER BY m.movieId,m.movieName
	FOR JSON PATH

GO


CREATE PROCEDURE spAvgUserScore
AS
	SELECT  DISTINCT m.movieId,									
			m.movieName,
			[avgUserScore] =	(
									 SELECT AVG(score) 
									 FROM tblPosts p 
										JOIN tblUsers u ON (u.userId = p.userId)
									 WHERE (p.movieId = m.movieId) AND (u.isCritic = 0)
								)
	FROM tblPosts p
		JOIN tblUsers u ON (u.userId = p.userId)
		JOIN tblMovies m ON (p.movieId = m.movieId)
	WHERE u.isCritic = 0
	GROUP BY p.score,p.userId, u.userId, u.isCritic, m.movieId, m.movieName
	ORDER BY m.movieId,m.movieName
	FOR JSON PATH

GO


CREATE PROCEDURE spAvgScore
AS
	SELECT 	DISTINCT m.movieId,
			m.movieName,
			[avgScore] =   (
								SELECT AVG(score) 
								FROM tblPosts p 
								WHERE p.movieId = m.movieId
							)
	FROM tblPosts p
		INNER JOIN tblMovies m ON (p.movieId = m.movieId)
	GROUP BY p.score, m.movieId, m.movieName
	ORDER BY m.movieId,m.movieName
	FOR JSON PATH

GO


CREATE PROCEDURE spGetUserPosts
	@userName VARCHAR(20)
AS
	SELECT  DISTINCT u.userId,
			u.userName,
			[userPosts] = (
								SELECT postId
								FROM tblPosts 
								WHERE u.userId = userId AND isDeleted = 0
								FOR JSON PATH
							)
	FROM tblUsers u
		JOIN tblPosts p ON (u.userId = p.userId)
	WHERE	(u.userName = @userName) AND
			(p.isDeleted = 0)
	ORDER BY userId, userName
	FOR JSON PATH

GO


CREATE PROCEDURE spGetDirectorFilms
	@directorId INT
AS
	SELECT  directorId,
			[fullName] = u.firstName + ' ' + u.lastName,
			[Movies] = (SELECT movieName,movieId FROM tblMovies m WHERE m.movieId = d.movieId FOR JSON PATH)
	FROM tblDirectors d
		JOIN tblUsers u ON (d.directorId = u.userId)
	WHERE directorId = 6
	FOR JSON PATH

GO


CREATE PROCEDURE spGetUserDeletedPosts
	@userId INT
AS
	SELECT  u.userId,
			u.userName,
			[userPosts] = (
								SELECT postId
								FROM tblPosts
								WHERE isDeleted = 1 AND userId = u.userId
								FOR JSON PATH
							)
	FROM tblUsers u
		JOIN tblPosts p ON (u.userId = p.userId)
	WHERE	(u.userId = @userId) AND
			(p.isDeleted = 1)
	ORDER BY userId, userName
	FOR JSON PATH

GO


CREATE PROCEDURE spGetUsersWhoHaveNotPosted
AS
	SELECT	DISTINCT u.userId,
			u.userName
	FROM tblUsers u, tblPosts p
	WHERE u.userId NOT IN(SELECT userId FROM tblPosts)
	ORDER BY u.userId
	FOR JSON PATH

GO


CREATE PROCEDURE spGetDirectors
AS
	SELECT	DISTINCT u.userId,
			u.age,
			u.email,
			u.password,
			[fullName] = u.firstName + ' ' + u.lastName
	FROM tblUsers u, tblDirectors d
	WHERE u.userId = d.directorId
	ORDER BY u.userId,fullName,u.age,u.email
	FOR JSON PATH

GO

--CREATE PROCEDURE spCreateUser
--	@userName	VARCHAR(20),
--	@password	VARCHAR(20),
--	@age		INT,
--	@isCritic	BIT,
--	@firstName	VARCHAR(50),
--	@lastName	VARCHAR(50),
--	@email		VARCHAR(50)
--AS
--	INSERT INTO tblUsers(userName, age, 
--						 isCritic, firstName,
--						 lastName, email,
--						 password)
--				VALUES  (@userName, @age,
--						 @isCritic, @firstName,
--						 @lastName, @email,
--						 @password)

--GO


--CREATE PROCEDURE spCreatePost
--	@userName	VARCHAR(20),
--	@movieName	VARCHAR(50),
--	@score		FLOAT,
--	@review		VARCHAR(500)
--AS

--	INSERT INTO tblPosts   (userId,
--							movieId,
--							score,
--							review,
--							datePosted,
--							isDeleted)
--					VALUES ((SELECT userId FROM tblUsers u WHERE u.userName = @userName),
--							(SELECT movieId FROM tblMovies m WHERE m.movieName = @movieName),
--							@score,
--							@review,
--							CURDATE(),
--							1)

	
	