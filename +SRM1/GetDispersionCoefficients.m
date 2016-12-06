function [A, B, C, Alpha, Structure] = GetDispersionCoefficients(StreetClass, varargin)
    % GetDispersionCoefficients
    %
    % Returns the SRM1 dispersion coefficients for the requested road type.
    %
    % USAGE
    % [A, B, C, Alpha, Struct] = SRM1.GetDispersionCoefficients(StreetClass)
    % [A, B, C, Alpha, Struct] = SRM1.GetDispersionCoefficients(StreetClass, 'SourceFile', sourceFile)
    %
    % INPUTS
    % StreetClass    - string
    %                One of 'Narrow Canyon', 'Wide Canyon', 'One Sided
    %                Canyon', or 'Not A Canyon'
    %
    % OPTIONAL ARGUMENTS
    % sourceFile     - string
    %                The path to a suitably structured .csv file containing
    %                the dispersion factors. If not set defaults to a
    %                standard file.
    %
    % OUTPUTS
    % A, B, C, Alpha - numeric scalers
    %                The SRM1 dispersion coefficients for the specified
    %                streetClass.
    % Struct         - struct
    %                All dispersion coefficients for all road types.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   GetDispersionCoefficients.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 24 2016 11:59:32  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    Dir = fileparts(which('SRM1.GetDispersionCoefficients'));
    SF = [Dir, '\Data\DispersionFactors.csv'];
    Options = struct('SourceFile', SF);
    Options = checkArguments(Options, varargin);

    % Read the csv to get the values.
    FID = fopen(Options.SourceFile, 'r');
    line = fgetl(FID);
    Cols = strsplit(line, ',');
    
    [~, StI] = ismember('Street Class', Cols');
    [~, AI] = ismember('A', Cols');
    [~, BI] = ismember('B', Cols');
    [~, CI] = ismember('C', Cols');
    [~, AlphaI] = ismember('Alpha', Cols');
    Structure = struct;
    while ~feof(FID)
        line = fgetl(FID);
        line = strsplit(line, ',');
        StreetClassL = line{StI};
        A = str2double(line{AI}); B = str2double(line{BI});
        C = str2double(line{CI}); Alpha = str2double(line{AlphaI});
        if nargout < 5
            if isequal(StreetClassL, StreetClass)
                return
            end
        elseif nargout == 5
            StreetClassK = strrep(StreetClassL, ' ', '');
            Structure.(StreetClassK) = struct;
            Structure.(StreetClassK).A = A;
            Structure.(StreetClassK).B = B;
            Structure.(StreetClassK).C = C;
            Structure.(StreetClassK).Alpha = Alpha;
        end
    end
    fclose(FID);
end