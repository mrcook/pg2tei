@ECHO OFF
ECHO AUTOMATED EMPHASIS TAGGER
ECHO Convert emphasised UPPERCASE text to <emph>lowercase</emph> text.
ECHO.

:: Any redistributions of files must retain the copyright notice below.

:: @author     Michael Cook | ePub Books (http://www.epubbooks.com)
:: @copyright  Copyright (c)2007-2009 Michael Cook
:: @package    tei.bat
:: @created    May 2007
:: @version    $Id$

\xampp\perl\bin\perl.exe -w \project-code\epubbooks-pg2tei\emph2lower.pl