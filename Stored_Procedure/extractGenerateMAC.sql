use [DatabaseName]
go

-- Set ansi nulls
set ansi_nulls on
go

-- Set quoted identifier
set quoted_identifier on
go

-- =================================
--        File: extractGenerateMAC
--     Created: 08/06/2020
--     Updated: 08/27/2020
--  Programmer: Cuates
--   Update By: Cuates
--     Purpose: Extract generate MAC
-- =================================
create procedure [dbo].[extractGenerateMAC]
  -- Parameters
  @optionMode nvarchar(255),
  @macGenerationQuantity nvarchar(255) = null
as
begin
  -- Set nocount on added to prevent extra result sets from interfering with select statements
  set nocount on

  -- Declare variables
  declare @attempts as smallint
  declare @currPos nvarchar(255) -- Current position
  declare @macFamily nvarchar(255) -- Mac family
  declare @stringPartOne nvarchar(255) -- String part one
  declare @stringPartTwo nvarchar(255) -- String part two
  declare @generatedMac nvarchar(255) -- Initial Entry for first mac number
  declare @possCharCount int -- Get possible character count
  declare @prevSubstring varchar(max) -- Get previous substring
  declare @buildMac nvarchar(max) -- Get build mac
  declare @macQuantity int -- Get mac quantity
  declare @lenBuildMac int -- Get length of build mac
  declare @stringStringLimit nvarchar(max) -- Get string mac limit
  declare @prevPos int -- Get previous position
  declare @buildMacReverse nvarchar(max) -- Get build mac in reverse
  declare @lenDecrementedString int -- Get length of decremented string
  declare @currCharacterPossPos int -- Get current character possible position
  declare @calCharacterPossPos int -- Get calculated character possible position
  declare @modCharacterPossPos int -- Get modulo of character possible position
  declare @badWordCount int -- Get bad word count
  declare @currBadWordPos int -- Get current bad word position
  declare @badWordComparisonValue int -- Get bad word comparison value
  declare @badWordComparisonString nvarchar(max) -- Get bad word comparison string
  declare @completedMacString nvarchar(max) -- Get completed mac string

  -- Set variables
  set @attempts = 1

  -- Declare a bad word temporary table
  declare @badWordTemp table
  (
    bwtID int identity (1, 1) primary key,
    badWord nvarchar(max) null
  )

  -- Declare a possible character temporary table
  declare @possibleCharacterTemp table
  (
    pctID int identity (1, 1) primary key,
    possbileCharacter nvarchar(255) null
  )

  -- Omit characters
  set @optionMode = dbo.OmitCharacters(@optionMode, '48,59,50,51,52,53,54,55,56,57,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122')

  -- Check if empty string
  if @optionMode = ''
    begin
      -- Set parameter to null if empty string
      set @optionMode = nullif(@optionMode, '')
    end

  -- Omit characters
  set @macGenerationQuantity = dbo.OmitCharacters(@macGenerationQuantity, '48,59,50,51,52,53,54,55,56,57')

  -- Check if empty string
  if @macGenerationQuantity = ''
    begin
      -- Set parameter to null if empty string
      set @macGenerationQuantity = nullif(@macGenerationQuantity, '')
    end

  -- Check if option mode is extract mac
  if @optionMode = 'extractMac'
    begin
      -- Select record
      select
      gm.generated_mac as [Generated Mac],
      gm.mac_family as [Mac Family],
      'Success~Extracted mac' as [Status]
      from dbo.GeneratedMac gm
      where
      gm.mac_family = @macFamily
      order by gm.generated_mac desc
    end

  -- Check if option mode is generate mac
  else if @optionMode = 'generateMac'
    begin
      --  Check if parameter is null or less than or equal to zero
      if @macGenerationQuantity is null or @macGenerationQuantity <= 0
        begin
          -- Set variable
          set @macGenerationQuantity = 1
        end

      -- Set variables
      set @currPos = 0
      set @macFamily = 'MacFamily'
      set @stringPartOne = '00:00:00'
      set @stringPartTwo = '00:00:00'
      set @stringStringLimit = 'FFFFFF' -- String to match for the last six characters
      set @calCharacterPossPos = 0

      -- Loop until condition is met
      while @attempts <= 5
        begin
          -- Begin the tranaction
          begin tran
            -- Begin the try block
            begin try
              -- Loop until condition is met
              while @currPos < @macGenerationQuantity
                begin
                  -- Set variable with generated mac
                  set @generatedMac = @stringPartOne + @stringPartOne

                  -- Check if there are no existing records for the mac family
                  if ((select count(*) as [macCount] from dbo.GeneratedMac gs where gs.mac_family = @macFamily) <= 0)
                    begin
                      -- Check if record does not exist based on generated mac and mac family
                      if not exists
                      (
                        -- Select record
                        select
                        top 1
                        gm.gmID as [gmID]
                        from dbo.GeneratedMac gm
                        where
                        gm.generated_mac = @generatedMac and
                        gm.mac_family = @macFamily
                        order by gm.gmID desc
                      )
                        begin
                          -- Insert first generated mac manually to start it off
                          -- The first generated mac will not be used unless the end user requests it
                          insert into dbo.GeneratedMac (generated_mac, mac_family) values (@generatedMac, @macFamily)
                        end

                      -- Increment position
                      set @currPos = @currPos + 1
                    end

                  -- Else check if record does not exist based on a substring of the generated mac and mac family
                  else if not exists
                  (
                    -- Select record
                    select
                    top 1
                    gm.generated_mac as [generated_mac]
                    from dbo.GeneratedMac gm
                    where
                    gm.generated_mac = @generatedMac and
                    gm.mac_family = @macFamily
                    order by gm.gmID desc
                  )
                    begin
                      -- Check if record does not exist based on generated mac and mac family
                      if not exists
                      (
                        -- Select record
                        select
                        top 1
                        gm.gmID as [gmID]
                        from dbo.GeneratedMac gm
                        where
                        gm.generated_mac = @generatedMac and
                        gm.mac_family = @macFamily
                      )
                        begin
                          -- Insert first generated mac manually to start it off
                          -- The first generated mac will not be used unless the end user requests it
                          insert into dbo.GeneratedMac (generated_mac, mac_family) values (@generatedMac, @macFamily)
                        end

                      -- Increment current position
                      set @currPos = @currPos + 1
                    end

                  -- Else generate mac
                  else
                    begin
                      -- Set variable
                      set @generatedMac = ''

                      -- Insert less than or equal to one thousand values into the temporary table for matching of bad words
                      insert into @badWordTemp (badwords) values ('BADWORD01'), ('BADWORD02')

                      -- Insert possible character string values into temporary table
                      insert into @possibleCharacterTemp (possbileCharacter) values ('0'), ('1'), ('2'), ('3'), ('4'), ('5'), ('6'), ('7'), ('8'), ('9'), ('A'), ('B'), ('C'), ('D'), ('E'), ('F')

                      -- Set variable with possible character count based on possible character temporary table
                      set @possCharCount =
                      (
                          -- Select record
                        select
                        count(*)
                        from @possibleCharacterTemp
                      )

                      -- Set variable with mac quantity
                      set @macQuantity = @currPos

                      -- Set variable with previous mac string
                      set @generatedMac =
                      (
                        -- Select record
                        select
                        top 1
                        stuff
                        (
                          stuff
                          (
                            stuff
                            (
                              stuff
                              (
                                stuff(gm.generated_mac, 3, 1, ''), 5, 1, ''
                              ), 7, 1, ''
                            ), 9, 1, ''
                          ), 11, 1, ''
                        ) as [generated_mac]
                        from dbo.GeneratedMac gm
                        where
                        gm.mac_family = @macFamily
                        order by gm.gmID desc
                      )

                      -- Set variable with a substring of the previous generated mac
                      set @prevSubstring = substring(@generatedMac, 7, 6)

                      -- Set variable with the substring of the previous generated mac
                      set @buildMac = @prevSubstring

                      -- Loop until condition is met for n amount of generated macs
                      while @macQuantity < @macGenerationQuantity
                        begin
                          -- Check if record does not exists based on build mac
                          if not exists
                          (
                            -- Select record
                            select
                            badWord
                            from @badWordTemp
                            where
                            badWord = @buildMac
                          )
                            begin
                              -- Set variable with a substring of the previous generated mac
                              set @prevSubstring =
                              (
                                -- Select record
                                select
                                top 1
                                substring(gm.generated_mac, 7, 6)
                                from dbo.GeneratedMac gm
                                where
                                gm.mac_family = @macFamily
                                order by gm.gmID desc
                              )

                              -- Set variable with a substring of the previous generated mac
                              set @buildMac = @prevSubstring
                            end

                          -- Set variable with length value of the build mac
                          set @lenBuildMac =
                          (
                            -- Select record
                            select
                            len(@buildMac)
                          )

                          -- Check if build string and string mac limit match
                          if @buildMac = @stringStringLimit
                            begin
                              -- Select record
                              select
                              'Error~Exceeded Mac Number Limit' as [Status]

                              -- Break out of stored procedure
                              return
                            end

                          -- Set variables
                          set @prevPos = 1
                          set @buildMacReverse = ''

                          -- Set variable with length of the build mac
                          set @lenDecrementedString = @lenBuildMac

                          -- Loop until condition is met based on the decrementing string length
                          while @lenDecrementedString > 0
                            begin
                              -- Set variable
                              set @currCharacterPossPos = 0

                              -- Set variable with a character string based on a substring of build mac and length of the decrementing string
                              set @currCharacterPossPos =
                              (
                                -- Select record
                                select
                                pctID
                                from @possibleCharacterTemp
                                where
                                possbileCharacter = substring(@buildMac, @lenDecrementedString, 1)
                              )

                              -- Check if the varaible is set and not an empty string
                              if @currCharacterPossPos is null or @currCharacterPossPos = ''
                                begin
                                  -- Set variable
                                  set @currCharacterPossPos = 0
                                end

                              -- Set variable with calculated current character possible position added with the previous position
                              set @calCharacterPossPos = @currCharacterPossPos + @prevPos

                              -- Set variable with the modulo value based on calculated character possible position and possible character count
                              set @modCharacterPossPos = @calCharacterPossPos % @possCharCount

                              -- Set variable with the string character starting from the right most character based on the modulo value
                              set @buildMacReverse = @buildMacReverse +
                              (
                                -- Select record
                                select
                                possbileCharacter
                                from @possibleCharacterTemp
                                where
                                pctID = @modCharacterPossPos
                              )

                              -- Check if variable values are equal to each other
                              if @calCharacterPossPos = @possCharCount
                                begin
                                  -- Set variable with the floor of possible character count divided by calculated character possible position
                                  set @prevPos = floor(@possCharCount/@calCharacterPossPos)
                                end
                              else
                                begin
                                  -- Else set variable with the floor of calculcated character possible position divided by possible character count
                                  set @prevPos = floor(@calCharacterPossPos/@possCharCount)
                                end

                              -- Decrement the length of the string
                              set @lenDecrementedString = @lenDecrementedString - 1
                            end

                          -- Set variable by reversing the string of build mac reverse
                          set @buildMac = reverse(@buildMacReverse)

                          -- Set variables
                          set @badWordCount =
                          (
                            -- Select record
                            select
                            count(*)
                            from @badWordTemp
                          )
                          set @currBadWordPos = 0
                          set @badWordComparisonValue = 0

                          -- Loop until condition is met based on all possible bad words in the temporary table
                          while @currBadWordPos <= @badWordCount
                            begin
                              -- Set variable with one bad word in the temporary table
                              set @badWordComparisonString =
                              (
                                -- Select record
                                select
                                badWord
                                from @badWordTemp
                                where
                                bwtID = @currBadWordPos
                              )

                              -- Set variable with the matched position of the compared build mac
                              set @badWordComparisonValue =
                              (
                                -- Select character index
                                select
                                charindex(@badWordComparisonString, @buildMac)
                              )

                              --  If value is null
                              if @badWordComparisonValue is null
                                begin
                                  -- Set variable with zero as bad word was not found
                                  set @badWordComparisonValue = 0
                                end

                              -- Check if bad word was found
                              if @badWordComparisonValue > 0
                                begin
                                  -- Break from while loop as there was a bad word found
                                  break
                                end

                              -- Increment position
                              set @currBadWordPos = @currBadWordPos + 1
                            end

                          -- Check if bad word was not found
                          if @badWordComparisonValue <= 0
                            begin
                              -- Increment mac quantity
                              set @macQuantity = @macQuantity + 1

                              -- Increment current position
                              set @currPos = @currPos + 1

                              -- Set variable with the build mac
                              set @completedMacString = @buildMac

                              -- Set variable
                              set @generatedMac = ''

                              -- Set variable with all sub string parts
                              set @generatedMac =
                              (
                                select
                                stuff
                                (
                                  stuff
                                  (
                                    stuff
                                    (
                                      stuff
                                      (
                                        stuff(@stringPartOne + @completedMacString, 3, 0, ':'), 6, 0, ':'
                                      ), 9, 0, ':'
                                    ), 12, 0, ':'
                                  ), 15, 0, ':'
                                )
                              )

                              -- Check if record does not exist based on generated mac and mac family
                              if not exists
                              (
                                -- Select record
                                select
                                top 1
                                gm.ID as [gmID]
                                from dbo.GeneratedMac gm
                                where
                                gm.generated_mac = @generatedMac and
                                gm.mac_family = @macFamily
                              )
                                begin
                                  -- Insert record into generated mac table
                                  insert into dbo.GeneratedMac (generated_mac, mac_family) values (@generatedMac, @macFamily)
                                end
                            end
                          -- Else do nothing as the generated mac was bad
                        end
                    end
                end

              -- Select record
              select
              'Success~Generated' + @macQuantity + ' mac(s)' as [Status]

              -- Check if there is trans count
              if @@trancount > 0
                begin
                  -- Commit transactional statement
                  commit tran
                end

              -- Break out of the loop
              break
            end try
            -- End try block
            -- Begin catch block
            begin catch
              -- Only display an error message if it is on the final attempt of the execution
              if @attempts = 5
                begin
                  -- Select error number, line, and message
                  select
                  'Error~generateMac: Error Number: ' + cast(error_number() as nvarchar) + ' Error Line: ' + cast(error_line() as nvarchar) + ' Error Message: ' + error_message() as [Status]
                end

              -- Check if there is trans count
              if @@trancount > 0
                begin
                  -- Rollback to the previous state before the transaction was called
                  rollback
                end

              -- Increments the loop control for attempts
              set @attempts = @attempts + 1

              -- Wait for delay for x amount of time
              waitfor delay '00:00:04'

              -- Continue the loop
              continue
            end catch
            -- End catch block
        end
    end
end