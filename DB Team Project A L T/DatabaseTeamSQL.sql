
-- If we ever change character lengths or names, change in procedures as well

-- I'd prefer avoiding compound CONSTRAINTs, making multiple or only naming PK & FK
-- Constraints should have consistent naming, like:
	-- PK -> thistable_pk
	-- FK -> thistable_columnreferenced_fk
	-- or whatever, as long as its consistent

-- 2 users: 
	-- 1. Database Manager ( all priveleges )
	-- 2. Server User ( possible IsAdmin )

--TODO: Drop database if it exists for easy recreation.
CREATE DATABASE ALTTeam;

CREATE TABLE Teams(
	TeamID		int				CONSTRAINT teamid_pk PRIMARY KEY,  -- IDENTITY(1,1)
	TeamName	nvarchar(30)	CONSTRAINT teamname_nn NOT NULL
);

-- Renamed Admin to IsAdmin because of future reserved keyword.
CREATE TABLE Users(
	UserID			int					CONSTRAINT user_userid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	FirstName		nvarchar(30)		CONSTRAINT user_fname_nn NOT NULL,
	LastName		nvarchar(30)		CONSTRAINT user_lname_nn NOT NULL,
	--Maybe have Prefereed use FirstName as default value?
	PreferredName	nvarchar(30)		CONSTRAINT user_prefname_nn NOT NULL,
	Password	varchar(30)		CONSTRAINT user_pswd_nn NOT NULL,
	IsAdmin			bit,
	CONSTRAINT users_compfl_uk UNIQUE (FirstName, LastName),
	CONSTRAINT users_comppl_uk UNIQUE (PreferredName. LastName)
);

CREATE TABLE TeamStudent(
	TeamID		int		CONSTRAINT teamstudent_team_nnfk NOT NULL REFERENCES Teams(TeamID),
	-- TODO: Separate constraints.
	UserID		int		CONSTRAINT teamstudent_user_uknnfk UNIQUE NOT NULL REFERENCES Users(UserID),
	CONSTRAINT teamstudent_pk PRIMARY KEY (TeamID, UserID)
);

CREATE TABLE Rubrics(
	RubricID	int				CONSTRAINT rubricid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	RubricName	varchar(15)		CONSTRAINT rubricname_nn NOT NULL
);

CREATE TABLE Sections(
	SectionID	int				CONSTRAINT sectionid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	RubricID	int				CONSTRAINT section_rubric_nnfk NOT NULL REFERENCES Rubrics(RubricID),
	SectionName	varchar(20)		CONSTRAINT sectioname_nn NOT NULL
);

-- Renamed Option to Options because of reserved keyword.
CREATE TABLE Options(
	OptionID	int				CONSTRAINT optionid_pk PRIMARY KEY,	-- IDENTITY(1,1)
	SectionID	int				CONSTRAINT sectopt_section_nnfk NOT NULL REFERENCES Sections(SectionID),
	OptionText	varchar(50)		CONSTRAINT optiontext_nn NOT NULL
);

-- While check contraints themselves apparently can't refer to other tables, UDFs can.
-- I don't know what exactly is required, so I'm slightly going off of microsoft documentation.
IF OBJECT_ID (N'dbo.IsValidOptionSection', N'TF') IS NOT NULL  -- No point in doing this if we're not recreating everything
    DROP FUNCTION dbo.IsValidOptionSection;  
GO  
CREATE FUNCTION dbo.IsValidOptionSection(@InputOptionID int, @InputSectionID int)
RETURNS bit
AS
BEGIN
	DECLARE @ret bit;
	DECLARE @result TABLE -- changed to be a table, was errored before
	(
		OptionID int,
		SectionID int
	)
	SET @result = (SELECT OptionID, SectionID
		    FROM Options
		    WHERE OptionID = InputOptionID AND SectionID = InputSectionID);
	--Unknown if I can just return the check itself.
	IF (@result IS NULL)
	    SET @ret = 0; -- This wasn't a valid option section combo.
	ELSE
	    SET @ret = 1; -- This was a valid option section combo.

	-- IF (SELECT OptionID, SectionID
	--	    FROM Options
	--	    WHERE OptionID = InputOptionID AND SectionID = InputSectionID) IS NULL
	--			RETURN 0;
	-- ELSE RETURN 1;

	
	RETURN @ret;
END

GO

IF OBJECT_ID (N'dbo.IsInSameTeam', N'TF') IS NOT NULL  -- No point in doing this if we're not recreating everything
    DROP FUNCTION dbo.IsInSameTeam;  
GO  
CREATE FUNCTION dbo.IsInSameTeam(@Person1 int, @Person2 int)
RETURNS bit
AS
BEGIN
	DECLARE @ret bit;
	DECLARE @team1 int;
	DECLARE @team2 int;
	SET @team1 = (SELECT TeamID
		    FROM TeamStudent
		    WHERE UserID = Person1);
	SET @team2 = (SELECT TeamID
		    FROM TeamStudent
		    WHERE UserID = Person2);
	--Unknown if I can just return the check itself.
	IF (@team1 = @team2)
	    SET @ret = 0; -- They're in same team.
	ELSE
	    SET @ret = 1; -- They're from different teams.
	
	-- IF (SELECT 1 TeamID  FROM TeamStudent WHERE UserID = Person1) 
	--		= (SELECT TOP 1 TeamID FROM TeamStudent WHERE UserID = Person2)
	--			RETURN 0;
	-- ELSE RETURN 1;
	RETURN @ret;
END

GO

--Couldn't quite remember what was wanted for the composite primary key.
CREATE TABLE StudentEval(
	Evaluator	int		CONSTRAINT seval_student1_nnfk NOT NULL REFERENCES Users(UserID),
	Evaluatee	int		CONSTRAINT seval_student2_nnfk REFERENCES Users(UserID),
	SectionID	int,
	OptionID	int		CONSTRAINT seval_option_nnfk NOT NULL REFERENCES Options(OptionID),
	CONSTRAINT seval_comp_pk PRIMARY KEY (Evaluator, Evaluatee, SectionID),
	CONSTRAINT seval_isvalid CHECK (dbo.IsValidOptionSection(OptionID, SectionID) = 1
);
--TODO: Merge Peer and StudentEval into one table, because checks can be done in procedures.
CREATE TABLE PeerEval(
	Evaluator	int		CONSTRAINT peval_student1_nnfk NOT NULL REFERENCES Users(UserID),
	Evaluatee	int		CONSTRAINT peval_student2_fk REFERENCES Users(UserID),
	SectionID	int,
	OptionID	int		CONSTRAINT peval_option_nnfk NOT NULL REFERENCES Options(OptionID),
	CONSTRAINT peval_comp_pk PRIMARY KEY (Evaluator, Evaluatee, SectionID),
	CONSTRAINT peval_isonteam CHECK (dbo.IsInSameTeam(Evaluator, Evaluatee) = 1), -- Replace with check in Student_EvalForm.
	CONSTRAINT peval_isvalid CHECK (dbo.IsValidOptionSection(OptionID, SectionID) = 1)
);

CREATE TABLE TeamEval(
	Evaluator	int		CONSTRAINT teval_student_nnfk NOT NULL REFERENCES Users(UserID),
	Evaluatee	int		CONSTRAINT teval_team_fk REFERENCES Teams(TeamID),
	SectionID	int,
	OptionID	int		CONSTRAINT teval_option_nnfk NOT NULL REFERENCES Options(OptionID),
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
	@UserName nvarchar(30) = NULL,
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
		IF @UserName is not NULL
			UPDATE Users
			SET UserName = @UserName
			WHERE UserID = @UserID;
		IF @IsAdmin is not NULL
			UPDATE Users
			SET IsAdmin = @IsAdmin
			WHERE UserID = @UserID;
		END
	ELSE IF ( @FirstName is not NULL AND @LastName is not NULL )
		BEGIN
		IF @UserName is NULL
			BEGIN
			SET @UserName = @FirstName
			END
		IF @IsAdmin is NULL
			BEGIN
			SET @IsAdmin = 0
			END
		INSERT INTO Users (FirstName, LastName, UserName, IsAdmin)
			VALUES ( @FirstName, @LastName, @UserName, @IsAdmin);
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


-- Possible Procedures --
-- CREATE PROCEDURE User_GetDetails
-- CREATE PROCEDURE Student_EvalForm -- ( Return either StudentEval OR PeerEval from 2 students)
-- CREATE PROCEDURE Student_InsertEval
-- CREATE PROCEDURE Student_GetAvgScore -- (Average for each section, separate for peer, team, studenteval)
-- CREATE PROCEDURE Student_GetComments
-- CREATE PROCEDURE Student_GetComments
-- CREATE PROCEDURE Students_GetNames
-- CREATE PROCEDURE Team_Delete
-- CREATE PROCEDURE Team_RemoveStudent -- admin only
-- CREATE PROCEDURE Team_GetStudents -- (pass in teamid for now)
-- CREATE PROCEDURE Team_EvalForm
-- CREATE PROCEDURE Team_InsertEval
-- CREATE PROCEDURE Team_GetAvgScore
-- CREATE PROCEDURE Team_GetComments
-- CREATE PROCEDURE Team_GetNames

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
