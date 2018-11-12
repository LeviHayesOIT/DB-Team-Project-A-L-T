
-- If we ever change character lengths or names, change in procedures as well

-- I'd prefer avoiding compound CONSTRAINTs, making multiple or only naming PK & FK
-- Constraints should have consistent naming, like:
	-- PK -> thistable_pk
	-- FK -> thistable_columnreferenced_fk
	-- or whatever, as long as its consistent

-- 2 users: 
	-- 1. Database Manager ( all priveleges )
	-- 2. Server User ( possible IsAdmin )
	-- 1. Database Manager ( all priveleges )

use master;
GO
IF DB_ID (N'ALTTeam') IS NOT NULL
DROP DATABASE ALTTeam;
GO

CREATE DATABASE ALTTeam;
GO

USE ALTTeam;
GO

CREATE TABLE Teams(
	TeamID		int				CONSTRAINT teamid_pk PRIMARY KEY,  -- IDENTITY(1,1)
	TeamName	nvarchar(30)	CONSTRAINT teamname_nn NOT NULL
);

-- Renamed Admin to IsAdmin because of future reserved keyword.
CREATE TABLE Users(
	UserID			int					CONSTRAINT user_userid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	FirstName		nvarchar(30)		CONSTRAINT user_fname_nn NOT NULL,
	LastName		nvarchar(30)		CONSTRAINT user_lname_nn NOT NULL,
	--Default doesn't easilly allow columns as the value.
	PreferredName	nvarchar(30)		CONSTRAINT user_prefname_nn NOT NULL ,
	Password	varchar(30)		CONSTRAINT user_pswd_nn NOT NULL,
	IsAdmin			bit,
	CONSTRAINT users_compfl_uk UNIQUE (FirstName, LastName),
	CONSTRAINT users_comppl_uk UNIQUE (PreferredName, LastName)
);

CREATE TABLE TeamStudent(
	TeamID		int		CONSTRAINT teamstudent_team_nn NOT NULL
						CONSTRAINT teamstudent_team_fk REFERENCES Teams(TeamID),
	
	UserID		int		CONSTRAINT teamstudent_user_uk UNIQUE
						CONSTRAINT teamstudent_user_nn NOT NULL
						CONSTRAINT teamstudent_user_fk REFERENCES Users(UserID),
	CONSTRAINT teamstudent_pk PRIMARY KEY (TeamID, UserID)
);

CREATE TABLE Rubrics(
	RubricID	int				CONSTRAINT rubricid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	RubricName	varchar(15)		CONSTRAINT rubricname_nn NOT NULL
);

CREATE TABLE Sections(
	SectionID	int				CONSTRAINT sectionid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	RubricID	int				CONSTRAINT section_rubric_nn NOT NULL
								CONSTRAINT section_rubric_fk REFERENCES Rubrics(RubricID),
	SectionName	varchar(20)		CONSTRAINT sectioname_nn NOT NULL
);

-- Renamed Option to Options because of reserved keyword.
CREATE TABLE Options(
	OptionID	int				CONSTRAINT optionid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	SectionID	int				CONSTRAINT sectopt_section_nn NOT NULL
								CONSTRAINT sectopt_section_fk REFERENCES Sections(SectionID),
	OptionText	varchar(50)		CONSTRAINT optiontext_nn NOT NULL
);

-- While check contraints themselves apparently can't refer to other tables, UDFs can.
-- I don't know what exactly is required, so I'm slightly going off of microsoft documentation.
-- TODO: Do we need the dbo. part?
IF OBJECT_ID (N'dbo.IsValidOptionSection', N'TF') IS NOT NULL -- Recreate it when the script is launched.
    DROP FUNCTION dbo.IsValidOptionSection;  
GO  
CREATE FUNCTION dbo.IsValidOptionSection(@InputOptionID int, @InputSectionID int)
RETURNS bit
AS
BEGIN
	DECLARE @ret bit;
	SET @ret = 1;
	DECLARE @result TABLE -- changed to be a table, was errored before
	(
		OptionID int,
		SectionID int
	);
	INSERT INTO @result 
			SELECT OptionID, SectionID
		    FROM Options
		    WHERE OptionID = @InputOptionID AND SectionID = @InputSectionID;

	IF NOT EXISTS(SELECT 1 FROM @result)
	    SET @ret = 0; -- This wasn't a valid option section combo.
	
	RETURN @ret;
	-- Side note: Attempting to have returns in an if-else block gets me errors.
END

GO

IF OBJECT_ID (N'dbo.IsInSameTeam', N'TF') IS NOT NULL -- Recreate it when the script is launched.
    DROP FUNCTION dbo.IsInSameTeam;  
GO  
CREATE FUNCTION dbo.IsInSameTeam(@Person1 int, @Person2 int)
RETURNS bit
AS
BEGIN
	DECLARE @ret bit;
	SET @ret = 0;
	DECLARE @team1 int;
	DECLARE @team2 int;
	SET @team1 = (SELECT TeamID
		    FROM TeamStudent
		    WHERE UserID = @Person1);
	SET @team2 = (SELECT TeamID
		    FROM TeamStudent
		    WHERE UserID = @Person2);
	
	IF (@team1 = @team2)
	    SET @ret = 1; -- They're in the same team.
	
	RETURN @ret;
END

GO

CREATE TABLE PersonEval(
	Evaluator	int		CONSTRAINT peval_student1_nn NOT NULL
						CONSTRAINT peval_student1_fk REFERENCES Users(UserID),
	Evaluatee	int		CONSTRAINT peval_student2_nn NOT NULL
						CONSTRAINT peval_student2_fk REFERENCES Users(UserID),
	SectionID	int,
	OptionID	int		CONSTRAINT peval_option_nn NOT NULL
						CONSTRAINT peval_option_fk REFERENCES Options(OptionID),
	CONSTRAINT peval_comp_pk PRIMARY KEY (Evaluator, Evaluatee, SectionID),
	CONSTRAINT peval_isvalid CHECK (dbo.IsValidOptionSection(OptionID, SectionID) = 1)
);

CREATE TABLE TeamEval(
	Evaluator	int		CONSTRAINT teval_student_nn NOT NULL
						CONSTRAINT teval_student_fk REFERENCES Users(UserID),
	Evaluatee	int		CONSTRAINT teval_team_nn NOT NULL
						CONSTRAINT teval_team_fk REFERENCES Teams(TeamID),
	SectionID	int,
	OptionID	int		CONSTRAINT teval_option_nn NOT NULL
						CONSTRAINT teval_option_fk REFERENCES Options(OptionID),
	CONSTRAINT teval_comp_pk PRIMARY KEY (Evaluator, Evaluatee, SectionID),
	CONSTRAINT teval_isvalid CHECK (dbo.IsValidOptionSection(OptionID, SectionID) = 1)
);

GO

-- We can prevent: 

CREATE PROCEDURE User_InsertUpdate	-- For admin use
(
	@ThisUserID int,	-- For checking Admin priveleges

	@UserID int = NULL,
	@FirstName nvarchar(30) = NULL,
	@LastName nvarchar(30) = NULL,
	@PreferredName nvarchar(30) = NULL,--Originally UserName, but Users doesn't have a UserName column.
	@IsAdmin bit = NULL
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
	IF @UserID is not NULL
		BEGIN
		IF @FirstName is not NULL
			UPDATE Users
			SET FirstName = @FirstName
			WHERE UserID = @UserID;
		IF @LastName is not NULL
			UPDATE Users
			SET LastName = @LastName
			WHERE UserID = @UserID;
		IF @PreferredName is not NULL
			UPDATE Users
			SET PreferredName = @PreferredName
			WHERE UserID = @UserID;
		IF @IsAdmin is not NULL
			UPDATE Users
			SET IsAdmin = @IsAdmin
			WHERE UserID = @UserID;
		END
	ELSE IF ( @FirstName is not NULL AND @LastName is not NULL )
		BEGIN
		IF @PreferredName is NULL
			BEGIN
			SET @PreferredName = @FirstName
			END
		IF @IsAdmin is NULL
			BEGIN
			SET @IsAdmin = 0
			END
		INSERT INTO Users (FirstName, LastName, PreferredName, IsAdmin)
			VALUES ( @FirstName, @LastName, @PreferredName, @IsAdmin);
		END
	END
END

GO

CREATE PROCEDURE User_Delete
(
	@ThisUserID int,	-- For checking Admin priveleges
	@UserID int
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
	DELETE FROM StudentEval WHERE Evaluator = @UserID OR Evaluatee = @UserID;
	DELETE FROM PeerEval WHERE Evaluator = @UserID OR Evaluatee = @UserID;
	DECLARE @TeamID int = ( SELECT TOP 1 TeamID FROM TeamStudent WHERE UserID = @UserID);
	DELETE FROM TeamStudent WHERE UserID = @UserID;
	DELETE FROM Users WHERE UserID = @UserID;
	IF @TeamID NOT IN (SELECT DISTINCT TeamID FROM TeamStudent)
		DELETE FROM Teams WHERE TeamID = @TeamID;
	END
END

GO

CREATE PROCEDURE Team_InsertUpdate
(
	@TeamID int = NULL,
	@TeamName nvarchar(30)
)
AS
BEGIN
IF @TeamID is not NULL
	UPDATE Teams SET TeamName = @TeamName WHERE TeamID = @TeamID;
ELSE
	INSERT INTO Teams (TeamName) VALUES (@TeamName);
END

GO

CREATE PROCEDURE Team_InsertStudent
(
	@TeamID int,
	@StudentID int
)
AS
BEGIN
IF @TeamID IN (SELECT DISTINCT TeamID FROM Teams) AND @StudentID NOT IN (SELECT DISTINCT UserID FROM TeamStudent)
	INSERT INTO TeamStudent (TeamID, UserID) VALUES (@TeamID, @StudentID)
END

GO

CREATE PROCEDURE User_GetDetails
(
	@CurrentStudentID int,
	@RequestedStudentID int
)
AS
BEGIN
	--If a user wants their own details, show it all (Except for ID and maybe admin status?).
	IF (@CurrentStudentID = @RequestedStudentID)
	BEGIN
		SELECT FirstName, PreferredName, LastName, Password, IsAdmin
		FROM Users
		WHERE UserID = @RequestedStudentID;
	END
	ELSE
	BEGIN--They're looking at someone else.
		SELECT PreferredName, LastName
		FROM Users
		WHERE UserID = @RequestedStudentID;
	END
END

GO



CREATE PROCEDURE Student_InsertEval
(
	@Evaluator int,
	@Evaluatee int,
	@SectionID int,
	@OptionID int
)
AS
BEGIN
	IF dbo.IsValidOptionSection(@OptionID, @SectionID) = 1
	BEGIN
		--If Evaluator, Evaluatee & Section has already been recorded, simply update the choice.
		IF EXISTS( SELECT Evaluator, Evaluatee, SectionID
					FROM PersonEval
					WHERE Evaluator = @Evaluator AND Evaluatee = @Evaluatee AND SectionID = @SectionID)
		BEGIN
			UPDATE PersonEval
			SET OptionID = @OptionID
			WHERE Evaluator = @Evaluator AND Evaluatee = @Evaluatee AND SectionID = @SectionID;
		END
		ELSE
		BEGIN
			INSERT INTO PersonEval(Evaluator, Evaluatee, SectionID, OptionID)
			VALUES (@Evaluator, @Evaluatee, @SectionID, @OptionID);
		END
	END
END

GO

CREATE PROCEDURE Students_GetStudents -- Returns id and name (preferredname, lastname), excluding the student themselves and all admins. If calling student is null, list everyone, not including admins.
(
	@CurrentStudentID int = NULL
)
AS
BEGIN
	IF @CurrentStudentID IS NOT NULL
	BEGIN
		SELECT UserID, PreferredName, LastName
		FROM Users
		WHERE IsAdmin <> 1 OR UserID <> @CurrentStudentID;
	END
	ELSE
	BEGIN
		SELECT UserID, PreferredName, LastName
		FROM Users
		WHERE IsAdmin <> 1;
	END
END

GO

CREATE PROCEDURE Team_Delete -- Removes team, deletes the teameval & teamstudent entries, too.
(
	@ThisUserID int,	-- For checking Admin priveleges
	@TeamID int
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		DECLARE @UsersInTeam int;
		SELECT @UsersInTeam = UserID
		FROM TeamStudent
		WHERE TeamID = @TeamID;

		DELETE FROM PersonEval
		WHERE Evaluatee IN (@UsersInTeam) AND Evaluator IN (@UsersInTeam);

		DELETE FROM TeamEval
		WHERE Evaluatee = @TeamID;

		DELETE FROM TeamStudent
		WHERE TeamID = @TeamID;

		DELETE FROM Teams
		WHERE TeamID = @TeamID;
	END
END

GO

CREATE PROCEDURE Team_GetStudents
(
	@TeamID int
)
AS
BEGIN
	SELECT PreferredName, LastName
	FROM TeamStudent JOIN Users ON TeamStudent.UserID = Users.UserID
	WHERE TeamID = @TeamID;
END

GO

CREATE PROCEDURE Team_RemoveStudent -- admin only
(
	@ThisUserID int,	-- For checking Admin priveleges
	@UserID int
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		DELETE FROM TeamStudent WHERE UserID = @UserID;
	END
END

GO

CREATE PROCEDURE Team_InsertEval
(
	@Evaluator int,
	@Evaluatee int,
	@SectionID int,
	@OptionID int
)
AS
BEGIN
	IF dbo.IsValidOptionSection(@OptionID, @SectionID) = 1
	BEGIN
		--If Evaluator, Evaluatee & Section has already been recorded, simply update the choice.
		IF EXISTS( SELECT Evaluator, Evaluatee, SectionID
					FROM TeamEval
					WHERE Evaluator = @Evaluator AND Evaluatee = @Evaluatee AND SectionID = @SectionID)
		BEGIN
			UPDATE TeamEval
			SET OptionID = @OptionID
			WHERE Evaluator = @Evaluator AND Evaluatee = @Evaluatee AND SectionID = @SectionID;
		END
		ELSE
		BEGIN
			INSERT INTO TeamEval(Evaluator, Evaluatee, SectionID, OptionID)
			VALUES (@Evaluator, @Evaluatee, @SectionID, @OptionID);
		END
	END
END

GO

CREATE PROCEDURE Team_GetNames
AS
BEGIN
	SELECT TeamName
	FROM Teams;
END

GO

--I felt like making Section & Option insertion/removal Eval-type independant.
--Section: ID, rubric, name
CREATE PROCEDURE Eval_SectionInsert
(
	@ThisUserID int,	-- For checking Admin priveleges
	@SectionID int = NULL,
	@Rubric int,
	@SectionName varchar(20)
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		if @SectionID IS NOT NULL
		BEGIN
			UPDATE Sections
			SET @SectionName = @SectionName
			WHERE SectionID = @SectionID;
		END
		ELSE
		INSERT INTO Sections (RubricID, SectionName) values(@Rubric, @SectionName);
	END
END

GO

CREATE PROCEDURE Eval_SectionDelete
(
	@ThisUserID int,	-- For checking Admin priveleges
	@SectionID int
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		DELETE FROM Sections WHERE SectionID = @SectionID;
	END
END

GO

CREATE PROCEDURE Eval_OptionInsert
(
	@ThisUserID int,	-- For checking Admin priveleges
	@OptionID int = NULL,
	@Section int,
	@OptionText varchar(50)
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		if @OptionID IS NOT NULL
		BEGIN
			UPDATE Options
			SET OptionText = @OptionText
			WHERE OptionID = @OptionID;
		END
		ELSE
		INSERT INTO Options (SectionID, OptionText) values(@Section, @OptionText);
	END
END

GO

CREATE PROCEDURE Eval_OptionDelete
(
	@ThisUserID int,	-- For checking Admin priveleges
	@OptionID int
)
AS
BEGIN
IF (SELECT TOP 1 IsAdmin FROM Users WHERE UserID = @ThisUserID ) = 1
	BEGIN
		DELETE FROM Options WHERE OptionID = @OptionID;
	END
END

GO


-- Possible Procedures --
-- CREATE PROCEDURE Student_EvalForm -- ( Return either StudentEval OR PeerEval from 2 students, based on IsInSameTeam)
-- CREATE PROCEDURE Student_GetAvgScore -- (Average for each section, separate for peer, team, studenteval)
-- CREATE PROCEDURE Student_GetComments -- Where do we put the comments in the database?
-- CREATE PROCEDURE Team_EvalForm
-- CREATE PROCEDURE Team_GetAvgScore
-- CREATE PROCEDURE Team_GetComments -- Also need to know where the team comments go.

-- CREATE PROCEDURE TeamEval_SectionInsert
-- CREATE PROCEDURE TeamEval_SectionDelete
-- CREATE PROCEDURE TeamEval_OptionInsert
-- CREATE PROCEDURE TeamEval_OptionDelete
-- CREATE PROCEDURE StudentEval_SectionInsert
-- CREATE PROCEDURE StudentEval_SectionDelete
-- CREATE PROCEDURE StudentEval_OptionInsert
-- CREATE PROCEDURE StudentEval_OptionDelete
-- CREATE PROCEDURE PeerEval_SectionInsert
-- CREATE PROCEDURE PeerEval_SectionDelete
-- CREATE PROCEDURE PeerEval_OptionInsert
-- CREATE PROCEDURE PeerEval_OptionDelete
