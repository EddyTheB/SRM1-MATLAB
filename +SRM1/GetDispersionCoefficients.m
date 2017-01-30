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
    %                the dispersion factors. If not set defaults to a set
    %                of values stored within this .m file. This is to
    %                ensure that the data can be compiled within the
    %                SRM1Display executable.
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

    %Dir = fileparts(which('SRM1.GetDispersionCoefficients'));
    %SF = [Dir, '\Data\DispersionFactors.csv'];
    %Options = struct('SourceFile', SF);
    Options = struct('SourceFile', 'Default');
    Options = checkArguments(Options, varargin);

    if ~isequal(Options.SourceFile, 'Default')
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
    else
        Structure = struct;
        Structure.NarrowCanyon.A = 4.8800e-04;
        Structure.NarrowCanyon.B = -0.0308;
        Structure.NarrowCanyon.C = 0.5900;
        Structure.NarrowCanyon.Alpha = 0;
        Structure.WideCanyon.A = 3.2500e-04;
        Structure.WideCanyon.B = -0.0205;
        Structure.WideCanyon.C = 0.3900;
        Structure.WideCanyon.Alpha = 0.8560;
        Structure.OneSidedCanyon.A = 5.0000e-04;
        Structure.OneSidedCanyon.B = -0.0316;
        Structure.OneSidedCanyon.C = 0.5700;
        Structure.OneSidedCanyon.Alpha = 0;
        Structure.NotACanyon.A = 3.1000e-04;
        Structure.NotACanyon.B = -0.0182;
        Structure.NotACanyon.C = 0.3300;
        Structure.NotACanyon.Alpha = 0.7990;
        StreetClass = strrep(StreetClass, ' ', '');
        A = Structure.(StreetClass).A;
        B = Structure.(StreetClass).B;
        C = Structure.(StreetClass).C;
        Alpha = Structure.(StreetClass).Alpha;
    end