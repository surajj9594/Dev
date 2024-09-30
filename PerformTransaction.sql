
--EXEC PerformTransaction
--@UserID =100,@Password = 'password1',@AccountNumber = 1234567890,@TransactionType='debit',@Amount=500

go
CREATE OR ALTER PROCEDURE PerformTransaction
    @UserID INT,
    @Password VARCHAR(50),
    @AccountNumber INT,
    @TransactionType VARCHAR(10),  -- 'debit' or 'credit'
    @Amount MONEY
AS
BEGIN
    -- Declare variables
    DECLARE @CurrentAmount MONEY;
    DECLARE @FailedAttempts INT;
    DECLARE @LastFailedAttempt DATETIME;
    DECLARE @CurrentTime DATETIME = GETDATE();
	DECLARE @Transaction_Date DATETIME = GETDATE();
    
    -- Check if the user exists in the LoginAttempts table
    IF EXISTS (SELECT 1 FROM LoginAttempts WHERE USER_ID = @UserID)
    BEGIN
        -- Get the number of failed attempts and the last failed attempt timestamp
        SELECT @FailedAttempts = FailedAttempts, @LastFailedAttempt = LastFailedAttempt
        FROM LoginAttempts WHERE USER_ID = @UserID;

        -- Check if the user has 3 failed attempts and if 3 minutes have not yet passed
        IF  @FailedAttempts >= 3 AND DATEADD(MINUTE, 3, @LastFailedAttempt) > @CurrentTime
        BEGIN
            -- Block the transaction and return an error message
            PRINT 'Your account is locked due to multiple failed login attempts. Please try again after 3 minutes.';
            RETURN;
        END
    END

    -- Check if User ID and Password match
    IF EXISTS (SELECT 1 FROM SBI_Customer WHERE USER_ID = @UserID AND Password = @Password AND AccountNumber = @AccountNumber)
    BEGIN
        -- If login is successful, reset the failed attempts
        IF EXISTS (SELECT 1 FROM LoginAttempts WHERE USER_ID = @UserID)
        BEGIN
            UPDATE LoginAttempts
            SET FailedAttempts = 0, LastFailedAttempt = NULL
            WHERE USER_ID = @UserID and LastFailedAttempt = DATEADD(MINUTE,3,@CurrentTime);
        END

        -- Get the current balance of the customer
        SELECT @CurrentAmount = Amount FROM SBI_Customer WHERE AccountNumber = @AccountNumber;

        -- Perform debit or credit based on the transaction type
        IF @TransactionType = 'debit'
        BEGIN
            -- Check if sufficient balance exists for debit
            IF @CurrentAmount >= @Amount
            BEGIN
                -- Update the balance by deducting the amount
                UPDATE SBI_Customer
                SET Amount = Amount - @Amount
                WHERE AccountNumber = @AccountNumber;

                PRINT 'Debit transaction successful';

                -- Insert the debit transaction into the TransactionLog table
                INSERT INTO Transaction_Log (AccountNumber, Transaction_Type, Transaction_Amount,Transaction_Date)
                VALUES (@AccountNumber, 'debit', @Amount,@Transaction_Date);
            END
            ELSE
            BEGIN
                PRINT 'Insufficient balance for the debit transaction';
            END
        END
        ELSE IF @TransactionType = 'credit'
        BEGIN
            -- Update the balance by adding the amount
            UPDATE SBI_Customer
            SET Amount = Amount + @Amount
            WHERE AccountNumber = @AccountNumber;

            PRINT 'Credit transaction successful';

            -- Insert the credit transaction into the TransactionLog table
            INSERT INTO Transaction_Log (AccountNumber, Transaction_Type, Transaction_Amount,Transaction_Date)
            VALUES (@AccountNumber, 'credit', @Amount,@Transaction_Date);
        END
        ELSE
        BEGIN
            PRINT 'Invalid transaction type. Use either "debit" or "credit".';
        END
    END
    ELSE
    BEGIN
        -- User ID or Password doesn't match

        -- If the user already exists in the LoginAttempts table, update failed attempts
        IF EXISTS (SELECT 1 FROM LoginAttempts WHERE USER_ID = @UserID)
        BEGIN
            UPDATE LoginAttempts
            SET FailedAttempts = FailedAttempts + 1, LastFailedAttempt = @CurrentTime
            WHERE USER_ID = @UserID;
        END
        ELSE
        BEGIN
            -- If user is not in the LoginAttempts table, insert a new record with 1 failed attempt
            INSERT INTO LoginAttempts (USER_ID, FailedAttempts, LastFailedAttempt)
            VALUES (@UserID, 1, @CurrentTime);
        END

        PRINT 'Error: Invalid User ID or Password';
    END
END;



