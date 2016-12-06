classdef SRM1Model < handle
    % SRM1Model
    % An implimentation of the Dutch SRM1 Model.
    %
    % All of the methods and properties have not been fully commented and
    % headed, that is a work in progress. It is recomended that the model
    % is opertaed using the SRM1Display GUI.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   SRM1Model.m  $
    % $Revision:   1.1  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 24 2016 10:17:18  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    properties
        % Calculation point properties.
        CalculationPointName
        CalculationPointType
        CalculationPointStreetName
        CalculationPointID
        DisplayObject = SRM1Display.empty

        % Road network properties.
        FileLocation = 'NoFile'
        RoadNetworkChangedMinor = 1
        RoadNetworkChangedMajor = 1
        EmissionFactorCatalogue = 'NotSet'
        BackgroundMapDirectory = 'NotSet'
    end
    
    properties (Hidden)
        % Model Parameters
        ParameterB = 0.6
        ParameterK = 100
        
        % The following properties are only used by the DisplayObject, if
        % set.
        DisplayModelledPointConcentrations = 0
        DisplayBackgroundMap = 1
        DisplayGrid = 1
        DisplayRoad = 1 
        Pollutant = 'NO2'
        CalculationDistanceModeAllowedValues = {'Road Edge', 'Road Centre'}
    end % properties (Hidden)
    
    properties (Dependent)
        AverageWindSpeed
        
        % The following have to do with calculation points. They are likely
        % to be matrices where atleast one dimension is the number of
        % calculation points.
        CalculationPoints
        NumPoints
        PointTrafficContributions
        PointConcentrations
        
        RoadNetwork
        NumRoads
        RoadTrafficContributions
        RoadConcentrations
        RoadConcentrationDistanceMode
        
        BackgroundO3
        BackgroundPM10
        BackgroundPM25
        BackgroundNOx
        BackgroundNO2
        
        EmissionFactorClassName
        EmissionFactorYear
        EmissionFactors
        EmissionFactorApportionment
        StagnantSpeedClass

        VehicleBreakdown
        VehicleScaling
        CP_X
        CP_Y
        CalculationDistance
        CalculationDistanceMode
    end % properties (Dependent)
    
    properties (Dependent, Hidden)
        % The following have to do with calculation points. They are likely
        % to be matrices where atleast one dimension is the number of
        % calculation points.
        PointRoadDetails
        PointRoadsImpacting % Roads within the impact distance, and judged to be impacting.
        PointRoadsCloseButNotImpacting % Roads within the impact distance but not judged to be impacting.
        PointRoadsCloseButNotImpactingReasons
        PointRoadsDistances
        PointRoadsImpactDistances
        PointMinRoadDistances
        PointNumRoadsImpacting
        PointRoadDispersionCoefficientsA
        PointRoadDispersionCoefficientsB
        PointRoadDispersionCoefficientsC
        PointRoadDispersionCoefficientsAlpha
        PointRoadTreeFactor
        PointRoadEmissionPM10
        PointRoadEmissionPM25
        PointRoadEmissionNO2
        PointRoadEmissionNOx
        PointBackgroundO3
        PointBackgroundPM10
        PointBackgroundPM25
        PointBackgroundNOx
        PointBackgroundNO2
        PointTrafficContributionsPM10
        PointTrafficContributionsPM25
        PointTrafficContributionsNOx
        PointTrafficContributionsNO2
        
        
        RoadBackgroundO3
        RoadBackgroundPM10
        RoadBackgroundPM25
        RoadBackgroundNOx
        RoadBackgroundNO2
        RoadTrafficContributionsPM10
        RoadTrafficContributionsPM25
        RoadTrafficContributionsNOx
        RoadTrafficContributionsNO2
        
        RoadPointConcentrations
    end % properties (Dependent, Hidden)
    
    properties (Hidden) %SetAccess = private, GetAccess = private)
        CalculationPointsP@double
        
        AverageWindSpeedP = 4
        
        PointRoadDetails60mP
        PointRoadDetails30mP
        PointRoadDetailsImpactP
        
        RoadImpactPoints60P
        RoadImpactPoints30P
        RoadImpactPointsImpactP
        
        PointTrafficContributionsP = struct.empty;
        RoadNetworkP@SRM1.RoadNetwork
        EmissionFactorClassNameP = 'Dutch'
        EmissionFactorYearP
        BackgroundO3P = 44
        BackgroundPM10P = 0
        BackgroundPM25P = 0
        BackgroundNOxP = 0
        BackgroundNO2P = 0
        BackgroundXYP = []
        CalculationDistanceP@double = 5
        CalculationDistanceModeP = 'Road Centre'
    end % properties (SetAccess = private, GetAccess = private)
    
    properties (SetAccess = private)
        DispersionCoefficients
    end
    
    methods
        %% Constructor
        function obj = SRM1Model()
            % Get the dispersion coefficients.
            [~, ~, ~, ~, obj.DispersionCoefficients] = SRM1.GetDispersionCoefficients('Narrow Canyon');
            % Get the emission factor catalogue.
            if isequal(obj.EmissionFactorCatalogue, 'NotSet')
                [dirEF, ~, ~] = fileparts(which('EmissionFactorsCat'));
                StandardEFFile = [dirEF, '\ProcessedData\StandardEmissionFactorCatalogue.efc'];
                obj.EmissionFactorCatalogue = EmissionFactorsCat(StandardEFFile);
                [obj.EmissionFactorYear, ~] = datevec(now);
            end
        end % function obj = SRM1Model()
        
        %% Getters
        function val = get.AverageWindSpeed(obj)
            val = obj.AverageWindSpeedP;
        end % function val = get.AverageWindSpeed(obj)
        
        function val = get.NumPoints(obj)
            [val, ~] = size(obj.CalculationPoints);
        end % function val = get.NumPoints(obj)
        
        function val = get.PointRoadsImpacting(obj)
            if obj.RoadNetworkChangedMajor || isempty(obj.PointRoadDetailsImpactP)
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.RoadsImpacting;
        end % function val = get.PointRoadsImpacting(obj)
        
        function val = get.PointRoadsCloseButNotImpacting(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.RoadsCloseButNotImpacting;
        end % function val = get.PointRoadsCloseButNotImpacting(obj)
        
        function val = get.PointRoadsCloseButNotImpactingReasons(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.RoadsCloseButNotImpactingReasons;
        end % function val = get.PointRoadsCloseButNotImpactingReasons(obj)

        function val = get.PointRoadsDistances(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.RoadsDistances;
        end % function val = get.PointRoadsDistances(obj)
        
        function val = get.PointRoadsImpactDistances(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.ImpactDistances;
        end % function val = get.PointRoadsImpactDistances(obj)
        
        function val = get.PointMinRoadDistances(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            obj.PointRoadDetailsImpactP
            val = obj.PointRoadDetailsImpactP.ClosestRoadDistances;
        end % function val = get.PointMinRoadDistances(obj)
     
        function val = get.PointNumRoadsImpacting(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.NumRoadsImpacting;
        end % function val = get.PointNumRoadsImpacting(obj)
        
        function val = get.PointRoadDispersionCoefficientsA(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.DispA;
        end % function val = get.PointRoadDispersionCoefficientsA(obj)
        
        
        function val = get.PointRoadDispersionCoefficientsB(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.DispB;
        end % function val = get.PointRoadDispersionCoefficientsB(obj)
        
        function val = get.PointRoadDispersionCoefficientsC(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.DispC;
        end % function val = get.PointRoadDispersionCoefficientsC(obj)
        
        function val = get.PointRoadDispersionCoefficientsAlpha(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.DispAlpha;
        end % function val = get.PointRoadDispersionCoefficientsAlpha(obj)
        
        function val = get.PointRoadTreeFactor(obj)
            %[NNN, ~] = size(obj.PointRoadTreeFactorP);
            %if NNN ~= obj.NumPoints
            %    % Not been assigned yet.
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
            end
            val = obj.PointRoadDetailsImpactP.Tree;
        end % function val = get.PointRoadTreeFactor(obj)
        
        function val = get.PointRoadEmissionPM10(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
                %obj.CalculatePointTrafficContributions
            end
            val = obj.PointRoadDetailsImpactP.EmPM10;
        end % function val = get.PointRoadEmissionPM10(obj)
        
        function val = get.PointRoadEmissionPM25(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
                %obj.CalculatePointTrafficContributions
            end
            val = obj.PointRoadDetailsImpactP.EmPM25;
        end % function val = get.PointRoadEmissionPM25(obj)
        
        function val = get.PointRoadEmissionNO2(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
                %obj.CalculatePointTrafficContributions
            end
            val = obj.PointRoadDetailsImpactP.EmNO2;
        end % function val = get.PointRoadEmissionNO2(obj)
        
        function val = get.PointRoadEmissionNOx(obj)
            if obj.RoadNetworkChangedMajor
                % Get the roads impacting.
                obj.GetRoadsImpacting
                %obj.CalculatePointTrafficContributions
            end
            val = obj.PointRoadDetailsImpactP.EmNOx;
        end % function val = get.PointRoadEmissionNOx(obj)

        function val = get.PointTrafficContributions(obj)
            if obj.RoadNetworkChangedMinor || isempty(obj.PointTrafficContributionsP)
                obj.CalculatePointTrafficContributions
            end
            val = obj.PointTrafficContributionsP;
        end % function val = get.PointTrafficContributionsPM10(obj)
        
        function val = get.PointTrafficContributionsPM10(obj)
            val = obj.PointTrafficContributions.PM10;
        end % function val = get.PointTrafficContributionsPM10(obj)
                
        function val = get.PointTrafficContributionsPM25(obj)
            val = obj.PointTrafficContributions.PM25;
        end % function val = get.PointTrafficContributionsPM25(obj)
                
        function val = get.PointTrafficContributionsNO2(obj)
            val = obj.PointTrafficContributions.NO2;
        end % function val = get.PointTrafficContributionsNO2(obj)
                
        function val = get.PointTrafficContributionsNOx(obj)
            val = obj.PointTrafficContributions.NOx;
        end % function val = get.PointTrafficContributionsNOx(obj)   
        
        function val = get.EmissionFactors(obj)
            AvailableYears = obj.EmissionFactorCatalogue.ApportionedFactorCatalogue.(obj.EmissionFactorClassName).YearVs;
            if ~ismember(obj.EmissionFactorYear, AvailableYears)
                error('SRM1Model not fine.')
            end
            val = obj.EmissionFactorCatalogue.ApportionedFactorCatalogue.(obj.EmissionFactorClassName);
        end % function val = get.EmissionFactors(obj)
        
        function val = get.EmissionFactorYear(obj)
            val = obj.EmissionFactorYearP;
        end % function val = get.EmissionFactorYear(obj)
        
        function val = get.EmissionFactorApportionment(obj)
            val = obj.EmissionFactorCatalogue.FactorApportionment;
        end % function val = get.EmissionFactorApportionment(obj)
        
        function val = get.PointConcentrations(obj)
            if obj.NumPoints
                CAll = struct;
                CAll.PM10 = obj.PointBackgroundPM10 + obj.PointTrafficContributionsPM10;
                CAll.PM25 = obj.PointBackgroundPM25 + obj.PointTrafficContributionsPM25;
                CAll.NOx = obj.PointBackgroundNOx + obj.PointTrafficContributionsNOx;
                CAll.NO2 = obj.PointBackgroundNO2 + obj.PointTrafficContributionsNO2;
                val = CAll;
            else
                CAll = struct;
                CAll.PM10 = [];
                CAll.PM25 = [];
                CAll.NOx = [];
                CAll.NO2 = [];
                val = CAll;
            end
        end % function val = get.PointConcentrations(obj)
        
        function val = get.RoadConcentrations(obj)
            CAll = struct;
            CAll.PM10 = obj.RoadBackgroundPM10 + obj.RoadTrafficContributionsPM10;
            CAll.PM25 = obj.RoadBackgroundPM25 + obj.RoadTrafficContributionsPM25;
            CAll.NOx = obj.RoadBackgroundNOx + obj.RoadTrafficContributionsNOx;
            CAll.NO2 = obj.RoadBackgroundNO2 + obj.RoadTrafficContributionsNO2;
            val = CAll;
        end % function val = get.RoadConcentrations(obj)
        
        function val = get.EmissionFactorClassName(obj)
            val = obj.EmissionFactorClassNameP;
        end % function val = get.EmissionFactor(obj)
        
        function val = get.BackgroundO3(obj)
            val = obj.GetBackground('O3', 1);
        end % function val = get.BackgroundO3(obj)
        
        function val = get.BackgroundNO2(obj)
            val = obj.GetBackground('NO2', 1);
        end % function val = get.BackgroundNO2(obj)
        
        function val = get.BackgroundNOx(obj)
            val = obj.GetBackground('NOx', 1);
        end % function val = get.BackgroundNOx(obj)
        
        function val = get.BackgroundPM10(obj)
            val = obj.GetBackground('PM10', 1);
        end % function val = get.BackgroundPM10(obj)
        
        function val = get.BackgroundPM25(obj)
            val = obj.GetBackground('PM25', 1);
        end % function val = get.BackgroundPM25(obj)
        
        function val = get.PointBackgroundO3(obj)
            val = obj.GetBackground('O3', obj.NumPoints);
        end % function val = get.PointBackgroundO3(obj)
        
        function val = get.PointBackgroundNO2(obj)
            val = obj.GetBackground('NO2', obj.NumPoints);
        end % function val = get.PointBackgroundNO2(obj)
        
        function val = get.PointBackgroundNOx(obj)
            val = obj.GetBackground('NOx', obj.NumPoints);
        end % function val = get.PointBackgroundNOx(obj)
        
        function val = get.PointBackgroundPM10(obj)
            val = obj.GetBackground('PM10', obj.NumPoints);
        end % function val = get.PointBackgroundPM10(obj)
        
        function val = get.PointBackgroundPM25(obj)
            val = obj.GetBackground('PM25', obj.NumPoints);
        end % function val = get.PointBackgroundPM25(obj)
        
        function val = get.RoadBackgroundO3(obj)
            val = obj.GetBackground('O3', obj.NumRoads);
        end % function val = get.RoadBackgroundO3(obj)
        
        function val = get.RoadBackgroundNO2(obj)
            val = obj.GetBackground('NO2', obj.NumRoads);
        end % function val = get.RoadBackgroundNO2(obj)
        
        function val = get.RoadBackgroundNOx(obj)
            val = obj.GetBackground('NOx', obj.NumRoads);
        end % function val = get.RoadBackgroundNOx(obj)
        
        function val = get.RoadBackgroundPM10(obj)
            val = obj.GetBackground('PM10', obj.NumRoads);
        end % function val = get.RoadBackgroundPM10(obj)
        
        function val = get.RoadBackgroundPM25(obj)
            val = obj.GetBackground('PM25', obj.NumRoads);
        end % function val = get.RoadBackgroundPM25(obj)
        
        function val = get.RoadTrafficContributions(obj)
            %TCString = sprintf('TrafficContributions%s', obj.Pollutant);
            TC.PM10 = obj.RoadNetwork.TrafficContributionsPM10;
            TC.PM25 = obj.RoadNetwork.TrafficContributionsPM25;
            TC.NO2 = obj.RoadNetwork.TrafficContributionsNO2;
            TC.NOx = obj.RoadNetwork.TrafficContributionsNOx;
            val = TC;
            %val = obj.RoadNetwork.(TCString);
        end % function val = get.RoadTrafficContributions(obj)
        
        function val = get.RoadTrafficContributionsPM10(obj)
            val = obj.RoadNetwork.TrafficContributionsPM10;
        end % function val = get.RoadTrafficContributionsPM10(obj)
        
        function val = get.RoadTrafficContributionsPM25(obj)
            val = obj.RoadNetwork.TrafficContributionsPM25;
        end % function val = get.RoadTrafficContributionsPM25(obj)
        
        function val = get.RoadTrafficContributionsNO2(obj)
            val = obj.RoadNetwork.TrafficContributionsNO2;
        end % function val = get.RoadTrafficContributionsNO2(obj)
        
        function val = get.RoadTrafficContributionsNOx(obj)
            val = obj.RoadNetwork.TrafficContributionsNOx;
        end % function val = get.RoadTrafficContributionsNOx(obj)
        
        function val = get.VehicleBreakdown(obj)
            val = obj.RoadNetwork.VehicleBreakdown;
        end % function get.VehicleBreakdown(obj)
        
        function val = get.VehicleScaling(obj)
            val = obj.RoadNetwork.VehicleScaling;
        end % function val = get.VehicleScaling(obj)
        
        function val = get.CP_X(obj)
            val = obj.GetCP('X');
        end % function val = get.CP_X(obj)
        
        function val = get.CP_Y(obj)
            val = obj.GetCP('Y');
        end % function val = get.CP_Y(obj)
        
        function val = GetCP(obj, XY)
            switch XY
                case {1, 'X'}
                    VV = 1;
                case {2, 'Y'}
                    VV = 2;
                otherwise
                    error('Unknown')
            end
            try
                val = obj.CalculationPoints(:, VV);
            catch E
                if isequal(E.identifier, 'MATLAB:badsubscript')
                    val = [];
                else
                    disp(E)
                    rethrow(E)
                end
            end
        end % function val = GetCP(obj, XY)
        
        function val = get.CalculationPoints(obj)
            val = obj.CalculationPointsP;
        end % function val = get.CalculationPoints(obj)
        
        function val = get.RoadNetwork(obj)
            val = obj.RoadNetworkP;
        end % function val = get.RoadNetwork(obj)
        
        function val = get.NumRoads(obj)
            val = obj.RoadNetwork.NumRoads;
        end % function val = get.NumRoads(obj)
        
        function val = get.CalculationDistance(obj)
            val = obj.CalculationDistanceP;
        end % function val = get.CalculationDistance(obj)
        
        function val = get.CalculationDistanceMode(obj)
            val = obj.CalculationDistanceModeP;
        end % function val = get.CalculationDistanceMode(obj)
        
        function val = get.RoadPointConcentrations(obj)
            BGString = ['Background', obj.Pollutant];
            BGValue = obj.(BGString);
            TCValue = obj.PointTrafficContributions.(obj.Pollutant);
            val = TCValue+BGValue;
        end % function val = get.RoadPointConcentrations(obj)
                     
        function val = get.StagnantSpeedClass(obj)
            val = obj.EmissionFactors.StagnantSpeedClass;
        end % function val = get.StagnantSpeedClass(obj)
        
        %% Setters
        function set.AverageWindSpeed(obj, val)
            if val < 0.5
                val = 0.5;
            elseif val > 20
                val = 20;
            end
            if ~isequal(val, obj.AverageWindSpeedP)
                obj.AverageWindSpeedP = val;
                obj.SendChanges
            end
        end % function set.AverageWindSpeed(obj, val)
        
        function set.CalculationPoints(obj, val)
            [a, b] = size(val);
            if b ~= 2
                error('SRM1Model:SetCalculationPoints:Not2Column', 'Calculation point should be a 2 column array.')
            end
            if ~isequal(val, obj.CalculationPointsP)
                obj.CalculationPointsP = val;
                obj.RoadNetworkChangedMinor = 1;
                obj.RoadNetworkChangedMajor = 1;
            end
            if a == 0
                obj.DisplayModelledPointConcentrations = 0;
            else
                obj.DisplayModelledPointConcentrations = 1;
            end
        end % function set.CalculationPoints(obj, val)
        
        function set.RoadNetwork(obj, val)
            if isempty(obj.RoadNetworkP)
                obj.RoadNetworkP = val;
                obj.RoadNetworkP.ModelObject = obj;
                obj.RoadNetworkChangedMinor = 1;
                obj.RoadNetworkChangedMajor = 1;
            end
        end % function set.RoadNetwork(obj, val)
        
        function set.EmissionFactorClassName(obj, val)
            if ~isequal(val, obj.EmissionFactorClassNameP)
                % First make sure that an emission factor structure with that
                % name is available in the catalogue.
                if ~ismember(val, obj.EmissionFactorCatalogue.FactorNames)
                    error('SRM1:SRM1Model:SetEmissionFactorClassName_A', 'EmissionFactorClassName must be set to one of the available names in the emission factor catalogue.')
                end
            
                obj.EmissionFactorClassNameP = val;
                obj.RoadNetwork.EmissionFactors = obj.EmissionFactors;
                obj.RoadNetworkChangedMinor = 1;
                obj.SendChanges
            end
        end % function set.EmissionFactorClassName(obj, val)
        
        function set.EmissionFactorYear(obj, val)
            obj.EmissionFactorYearP = val;
            try
                obj.RoadNetwork.EmissionFactorYear = val;
            catch err
                if ~isequal(err.identifier, 'MATLAB:emptyObjectDotAssignment')
                    disp(err)
                    rethrow(err)
                end
            end
            obj.SendChanges
        end % function val = get.EmissionFactorYear(obj)
        
        function set.EmissionFactorApportionment(obj, val)
            if ~isequal(val, obj.EmissionFactorCatalogue.FactorApportionment)
                obj.EmissionFactorCatalogue.FactorApportionment = val;
                obj.RoadNetwork.EmissionFactors = obj.EmissionFactors;
                obj.RoadNetworkChangedMinor = 1;
                obj.SendChanges
            end
        end % function set.EmissionFactorApportionment(obj, val)
               
                       
        function set.StagnantSpeedClass(obj, val)
            if ~isequal(val, obj.EmissionFactors.StagnantSpeedClass)
                obj.EmissionFactorCatalogue.FactorCatalogue.(obj.EmissionFactorClassName).StagnantSpeedClass = val;
                obj.RoadNetwork.EmissionFactors = obj.EmissionFactors;
                obj.RoadNetworkChangedMinor = 1;
                obj.SendChanges
            end
        end % function set.StagnantSpeedClass(obj, val)
        
        function set.BackgroundO3(obj, val)
            if ~isequal(val, obj.BackgroundO3P)
                obj.BackgroundO3P = val;
                if isequal(obj.Pollutant, 'NO2')
                    obj.SendChanges
                end
            end
        end % function set.BackgroundO3(obj, val)
        
        function set.BackgroundNO2(obj, val)
            if ~isequal(val, obj.BackgroundNO2P)
                obj.BackgroundNO2P = val;
                if isequal(obj.Pollutant, 'NO2')
                    obj.SendChanges
                end
            end
        end % function set.BackgroundNO2(obj, val)
        
        function set.BackgroundNOx(obj, val)
            if ~isequal(val, obj.BackgroundNOxP)
                obj.BackgroundNOxP = val;
                if isequal(obj.Pollutant, 'NOx')
                    obj.SendChanges
                end
            end
        end % function set.BackgroundNOx(obj, val)
        
        function set.BackgroundPM10(obj, val)
            if ~isequal(val, obj.BackgroundPM10P)
                obj.BackgroundPM10P = val;
                if isequal(obj.Pollutant, 'PM10')
                    obj.SendChanges
                end
            end
        end % function set.BackgroundPM10(obj, val)
        
        function set.BackgroundPM25(obj, val)
            if ~isequal(val, obj.BackgroundPM25P)
                obj.BackgroundPM25P = val;
                if isequal(obj.Pollutant, 'PM25')
                    obj.SendChanges
                end
            end
            obj.BackgroundPM25P = val;
        end % function set.BackgroundPM25(obj, val)
        
        function set.VehicleScaling(~, ~)
            error('SRM1Model:SetVehicleScaling:NoSet', 'The vehicle scaling property can not be assigned in that manner. Use the ''SetVehicleScaling'' function instead.')
        end % function set.VehicleScaling(~, ~)
        
        function set.CalculationDistance(obj, val)
            if ~isequal(val, obj.CalculationDistanceP)
                if val < 0
                    error('SRM1Model:SetCalculationDistance:NegativeNumber', 'CalculationDistance must be greater or equal to zero.')
                end
                obj.CalculationDistanceP = val;
                obj.RoadNetwork.CalculationDistance = val;
                obj.SendChanges
            end
        end % function set.CalculationDistance(obj, val)
        
        function set.CalculationDistanceMode(obj, val)
            if ~isequal(val, obj.CalculationDistanceModeP)
                if ~ismember(val, obj.CalculationDistanceModeAllowedValues)
                    error('SRM1Model:SetCalculationDistanceMode:BadValue', 'CalculationDistanceMode must be one of either ''%s'' or ''%s''.', obj.CalculationDistanceModeAllowedValues{1}, obj.CalculationDistanceModeAllowedValues{2})
                end
                obj.CalculationDistanceModeP = val;
                obj.RoadNetwork.CalculationDistanceMode = val;
                obj.SendChanges
            end
        end % function set.CalculationDistance(obj, val)
        
        function set.Pollutant(obj, val)
            if ~isequal(val, obj.Pollutant)
                obj.Pollutant = val;
                obj.SendChanges
            end
        end % function set.Pollutant(obj, val)
        
        %% Other functions.
        function SendChanges(obj)
            if ~isempty(obj.RoadNetwork)
                obj.RoadNetwork.ResetTrafficContributions;
                obj.PointTrafficContributionsP = struct.empty;
            end
            if ~isempty(obj.DisplayObject)
                obj.DisplayObject.SendChanges
            end
        end % function SendChanges(obj)
        
        function ResetRoadsImpacting(obj)
            % This will reset the fields that have to do with which roads
            % impact on which calculation points. After it has been called
            % any attempts to get traffic contributions will lead to these
            % fields being calculated again using a loop through all
            % calculation points, so it's quite time consuming.
            % The following situations will lead to it being called again:
            %     If calculation points are moved, removed or added.
            %     If roads are moved, removed, or added.
            %     If the road class of any road segment is changed (since
            %     different road types have different impact distances).
            obj.GetRoadsImpacting;
            obj.ResetPointTrafficContributions;
        end % function ResetRoadsImpacting(obj)
        
        
        function ResetPointTrafficContributions(obj)
            % This will reset the fields that directly lead to
            % concentration calculations, but not those that require a loop
            % though all calculation points (see ResetRoadsImpacting).
            % The following situations will lead to it being called again:
            %     If calculation points are moved, removed or added.
            %     If roads are moved, removed, or added.
            %     If the road class of any road segment is changed (since
            %     different road types have different impact distances).
            obj.PointTrafficContributionsP = struct.empty;
        end % function ResetPointTrafficContributions(obj)
        
        function ImportRoadNetwork(obj, filename)
            RN = SRM1.RoadNetwork.CreateFromShapeFile(filename, ...
                'EmissionFactors', obj.EmissionFactors, ...
                'DispersionCoefficients', obj.DispersionCoefficients, ...
                'EmissionFactorYear', obj.EmissionFactorYear);
            obj.RoadNetwork = RN;
            try
                obj.EmissionFactorClassName = obj.EmissionFactorClassNameP; % This will
                                      % check to make sure that the current
                                      % emission factor can be used with
                                      % this road network.
            catch err
                disp(err)
                fprintf('Error here. ABCDEFGHI\n')
                rethrow(err)
                % If the assigned emission factor name doesn't work, then
                % try another and issue a warning.
            end
            obj.RoadNetworkChangedMajor = 1;
            obj.RoadNetworkChangedMinor = 1;
        end % function ImportRoadNetwork(obj, VVVV, varargin)
        
        function ImportCalculationPoints(obj, VVVV, varargin)
            switch class(VVVV)
                case 'char'
                    % Assume it's a shape file.
                    S = shaperead(VVVV);
                    NumFeatures = numel(S);
                    Pts = nan(NumFeatures, 2);
                    Tps = cell(NumFeatures, 1);
                    Nms = cell(NumFeatures, 1);
                    IDs = nan(NumFeatures, 2);
                    for i = 1:NumFeatures
                        R = S(i);
                        if ~ismember(R.Geometry, {'Point', 'MultiPoint'})
                            error('SRM1Model:ImportCalculationPoint:NotPoint', 'Features should have point geometry, not %s geometry.', R.Geometry)
                        end
                        Pts(i, 1) = R.X;
                        Pts(i, 2) = R.Y;
                        try
                            Tps{i} = R.Type;
                        catch err
                            if isequal(err.identifier, 'MATLAB:nonExistentField')
                                Tps{i} = 'NotDefined';
                            else
                                disp(err)
                                rethrow(err)
                            end
                        end
                        try
                            Nms{i} = R.PointName;
                        catch err
                            if isequal(err.identifier, 'MATLAB:nonExistentField')
                                Nms{i} = 'NotDefined';
                            else
                                disp(err)
                                rethrow(err)
                            end
                        end
                        try
                            IDs(i) = R.PointID;
                        catch err
                            if isequal(err.identifier, 'MATLAB:nonExistentField')
                                IDs(i) = i;
                            else
                                disp(err)
                                rethrow(err)
                            end
                        end 
                    end
                    obj.CalculationPoints = Pts;
                    obj.CalculationPointType = Tps;
                    obj.CalculationPointStreetName = Nms;
                    obj.CalculationPointID = IDs;
                case 'double'
                    Options = struct('PointNames', 'NotSet', 'PointTypes', 'NotSet', ...
                        'PointStreetNames', 'NotSet', 'PointIDs', 'NotSet');
                    Options = checkArguments(Options, varargin);
                    if ~isequal(Options.PointNames, 'NotSet')
                        obj.CalculationPointName = Options.PointNames;
                    end
                    if ~isequal(Options.PointTypes, 'NotSet')
                        obj.CalculationPointType = Options.PointTypes;
                    end
                    if ~isequal(Options.PointStreetNames, 'NotSet')
                        obj.CalculationPointStreetName = Options.PointStreetNames;
                    end
                    if ~isequal(Options.PointIDs, 'NotSet')
                        obj.CalculationPointID = Options.PointIDs;
                    end
                    [A, B] = size(VVVV);
                    if B == 2
                        Pts = VVVV;
                    elseif A == 2
                        Pts = VVVV';
                    else
                        error('SRM1Model:ImportCalculationPoint:Not2Column', 'The calculation points grid should be a 2 column vector.')
                    end
                    obj.CalculationPoints = Pts;
                otherwise
                    error('SRM1Model:ImportCalculationPoint:WrongClass', 'Can''t understand calculation points of class ''%s''.', class(VVVV))
            end
            obj.RoadNetworkChangedMajor = 1;
            obj.RoadNetworkChangedMinor = 1;
        end % function ImportCalculationPoints(obj, filename)
        
        function val = GetPointConcentrations(obj, Pollutant)
            if isempty(obj.PointTrafficContributionsAll)
                obj.CalculatePointTrafficContributions;
            end
            val = obj.PointConcentrations.(Pollutant);
        end % function val = GetPointConcentrations(obj, Pollutant)
        
        function GetRoadsImpacting(obj, varargin)
            Options = struct('Plot', []);
            Options = checkArguments(Options, varargin);
            % Get all calculation Points.
            Pts = obj.CalculationPoints;
            NumPoints = obj.NumPoints;
            if NumPoints == 0
                fprintf('GetRoadsImpacting: No points assigned.\n')
                obj.PointRoadDetailsImpactP.NumRoadsImpacting = [];
                obj.PointRoadDetailsImpactP.RoadsImpacting = [];
                obj.PointRoadDetailsImpactP.RoadsCloseButNotImpacting = [];
                obj.PointRoadDetailsImpactP.RoadsCloseButNotImpactingReasons = [];
                obj.PointRoadDetailsImpactP.RoadsDistances = [];
                obj.PointRoadDetailsImpactP.ImpactDistances = [];
                obj.PointRoadDetailsImpactP.ClosestRoadDistances = [];
                obj.PointRoadDetailsImpactP.DispA = [];
                obj.PointRoadDetailsImpactP.DispB = [];
                obj.PointRoadDetailsImpactP.DispC = [];
                obj.PointRoadDetailsImpactP.DispAlpha = [];
                obj.PointRoadDetailsImpactP.Tree = [];
                obj.PointRoadDetailsImpactP.EmPM10 = [];
                obj.PointRoadDetailsImpactP.EmPM25 = [];
                obj.PointRoadDetailsImpactP.EmNO2 = [];
                obj.PointRoadDetailsImpactP.EmNOx = [];
                %Perhaps more required.
                return
            end
            if isequal(Options.Plot, 'All');
                Options.Plot = 1:NumPoints;
            end
            wb = waitbar(0, sprintf('Assessing which roads impact on point %d of %d.', 1, NumPoints), ...
                'CreateCancelBtn', ...
                'setappdata(gcbf, ''canceling'',1)');
            setappdata(wb, 'canceling', 0)
            
            % Prepare a structure to hold the details of roads within 60 m
            % of each point.
            Details60 = struct;
            Details60.NumRoadsImpacting = zeros(NumPoints, 1);
            Details60.RoadsImpacting = nan(NumPoints, 10);
            Details60.RoadsCloseButNotImpacting = nan(NumPoints, 10);
            Details60.RoadsCloseButNotImpactingReasons = nan(NumPoints, 10);
            Details60.RoadsDistances = nan(NumPoints, 10);
            Details60.ImpactDistances = nan(NumPoints, 10);
            Details60.ClosestRoadDistances = 999*ones(NumPoints, 1);
            Details60.DispA = nan(NumPoints, 10);
            Details60.DispB = nan(NumPoints, 10);
            Details60.DispC = nan(NumPoints, 10);
            Details60.DispAlpha = nan(NumPoints, 10);
            Details60.Tree = nan(NumPoints, 10);
            Details60.EmPM10 = nan(NumPoints, 10);
            Details60.EmPM25 = nan(NumPoints, 10);
            Details60.EmNO2 = nan(NumPoints, 10);
            Details60.EmNOx = nan(NumPoints, 10);

            % Loop through every point. This is why we want to avoid doing
            % this very often.
            PtsToDo = 1:NumPoints;
            NumCloseMax = 0;
            for PtI = PtsToDo
                if getappdata(wb, 'canceling')
                    delete(wb)
                    obj.PointTrafficContributionsAll = struct.empty;
                    return
                end
                waitbar(PtI/NumPoints, wb, sprintf('Assessing which roads impact on point %d of %d.', PtI, NumPoints))
                Pt = Pts(PtI, :);  
                % Find the roads within 60 metres that would be judged to
                % impact on the point.
                [Indices, CloseEnoughIndices, Reasons_, ~] = obj.RoadNetwork.RoadsImpacting(Pt, 60);
                % Indices lists the indices of those roads which are judged
                % to impact on the point. Close enough are those that are
                % within 60m. Identify those which are close enough but are
                % not judged to impact on the point.
                [~, IsInc] = ismember(Indices, CloseEnoughIndices);
                CloseEnoughNotIncluded_ = CloseEnoughIndices;
                CloseEnoughNotIncluded_(IsInc) = [];
                Reasons_(IsInc) = [];
                % Now prepare some arrays.
                NumRoads = numel(Indices);
                Distances_ = 999*ones(1, NumRoads);
                ImpactDistances_ = 60*ones(1, NumRoads);
                DispA_ = nan(1, NumRoads);
                DispB_ = nan(1, NumRoads);
                DispC_ = nan(1, NumRoads);
                DispAlpha_ = nan(1, NumRoads);
                Tree_ = nan(1, NumRoads);
                EmPM10_ = nan(1, NumRoads);
                EmPM25_ = nan(1, NumRoads);
                EmNO2_ = nan(1, NumRoads);
                EmNOx_ = nan(1, NumRoads);
                % And add to the structures created above.
                for RdI = 1:NumRoads
                    RoadIndex = Indices(RdI);
                    Rd = obj.RoadNetwork.RoadSegments(RoadIndex);
                    Vs = Rd.Vertices;
                    Distances_(RdI) = distancePointPolyline(Pt, Vs);
                    ImpactDistances_(RdI) = Rd.ImpactDistance;
                    DispA_(RdI) = Rd.DispersionCoefficients.A;
                    DispB_(RdI) = Rd.DispersionCoefficients.B;
                    DispC_(RdI) = Rd.DispersionCoefficients.C;
                    DispAlpha_(RdI) = Rd.DispersionCoefficients.Alpha;
                    Tree_(RdI) = Rd.TreeFactor;
                    EmPM10_(RdI) = Rd.Emissions.PM10;
                    EmPM25_(RdI) = Rd.Emissions.PM25;
                    EmNO2_(RdI) = Rd.Emissions.NO2;
                    EmNOx_(RdI) = Rd.Emissions.NOx;
                end
                Details60.NumRoadsImpacting(PtI) = NumRoads;
                Details60.RoadsImpacting(PtI, 1:NumRoads) = Indices;
                NumClose = numel(CloseEnoughNotIncluded_);
                if NumClose > NumCloseMax
                    NumCloseMax = NumClose;
                end
                Details60.RoadsCloseButNotImpacting(PtI, 1:NumClose) = CloseEnoughNotIncluded_;
                Details60.RoadsCloseButNotImpactingReasons(PtI, 1:NumClose) = Reasons_;
                if NumRoads
                    Details60.RoadsDistances(PtI, 1:NumRoads) = Distances_;
                    Details60.ImpactDistances(PtI, 1:NumRoads) = ImpactDistances_;
                    Details60.ClosestRoadDistances(PtI) = min(Distances_);
                    Details60.DispA(PtI, 1:NumRoads) = DispA_;
                    Details60.DispB(PtI, 1:NumRoads) = DispB_;
                    Details60.DispC(PtI, 1:NumRoads) = DispC_;
                    Details60.DispAlpha(PtI, 1:NumRoads) = DispAlpha_;
                    Details60.Tree(PtI, 1:NumRoads) = Tree_;
                    Details60.EmPM10(PtI, 1:NumRoads) = EmPM10_;
                    Details60.EmPM25(PtI, 1:NumRoads) = EmPM25_;
                    Details60.EmNO2(PtI, 1:NumRoads) = EmNO2_;
                    Details60.EmNOx(PtI, 1:NumRoads) = EmNOx_;
                else
                    Details60.ClosestRoadDistances(PtI) = 999;
                end
            end
            MaxRoadImpacting = max(Details60.NumRoadsImpacting);
            Details60.RoadsImpacting = Details60.RoadsImpacting(:, 1:MaxRoadImpacting);
            Details60.RoadsCloseButNotImpacting = Details60.RoadsCloseButNotImpacting(:, 1:NumCloseMax);
            Details60.RoadsCloseButNotImpactingReasons = Details60.RoadsCloseButNotImpactingReasons(:, 1:NumCloseMax);
            Details60.RoadsDistances = Details60.RoadsDistances(:, 1:MaxRoadImpacting);
            Details60.ImpactDistances = Details60.ImpactDistances(:, 1:MaxRoadImpacting);
            Details60.DispA = Details60.DispA(:, 1:MaxRoadImpacting);
            Details60.DispB = Details60.DispB(:, 1:MaxRoadImpacting);
            Details60.DispC = Details60.DispC(:, 1:MaxRoadImpacting);
            Details60.DispAlpha = Details60.DispAlpha(:, 1:MaxRoadImpacting);
            Details60.Tree = Details60.Tree(:, 1:MaxRoadImpacting);
            Details60.EmPM10 = Details60.EmPM10(:, 1:MaxRoadImpacting);
            Details60.EmPM25 = Details60.EmPM25(:, 1:MaxRoadImpacting);
            Details60.EmNO2 = Details60.EmNO2(:, 1:MaxRoadImpacting);
            Details60.EmNOx = Details60.EmNOx(:, 1:MaxRoadImpacting);
            
            Details30 = Details60;
            DetailsImpact = Details60;
            Fields = {'RoadsImpacting', 'RoadsCloseButNotImpacting', 'RoadsCloseButNotImpactingReasons', ...
                      'DispA', 'DispB', 'DispC', 'DispAlpha', 'Tree', 'EmPM10', 'EmPM25', 'EmNO2', 'EmNOx', ...
                      'RoadsDistances', 'ImpactDistances'};
            for Fi = 1:numel(Fields)
                F = Fields{Fi};
                Details30.(F)(Details30.RoadsDistances > 30) = nan;
                DetailsImpact.(F)(DetailsImpact.RoadsDistances > Details30.ImpactDistances) = nan;
            end
            DetailsImpact.RoadsDistances;
            
            % Now, for each road, get every point that is within 60, and 30
            % meters of it.
            RoadImpactPoints60P_ = zeros(obj.NumRoads, 40);
            RoadImpactPoints30P_ = RoadImpactPoints60P_ ;
            RoadImpactPointsImpactP_ = RoadImpactPoints60P_ ;
            for Ri = 1:obj.NumRoads
                [PtsI, ~] = find(Details60.RoadsImpacting == Ri);
                NumPoints = numel(PtsI);
                if NumPoints
                    RoadImpactPoints60P_(Ri, 1:NumPoints) = PtsI;
                end
                [PtsI, ~] = find(Details30.RoadsImpacting == Ri);
                NumPoints = numel(PtsI);
                if NumPoints
                    RoadImpactPoints30P_(Ri, 1:NumPoints) = PtsI;
                end
                [PtsI, ~] = find(DetailsImpact.RoadsImpacting == Ri);
                NumPoints = numel(PtsI);
                if NumPoints
                    RoadImpactPointsImpactP_(Ri, 1:NumPoints) = PtsI;
                end
            end
            
            RoadImpactPoints60P_(RoadImpactPoints60P_ == 0) = nan;
            RoadImpactPoints30P_(RoadImpactPoints30P_ == 0) = nan;
            RoadImpactPointsImpactP_(RoadImpactPointsImpactP_ == 0) = nan;
            delete(wb)

            obj.PointRoadDetails60mP = Details60;
            obj.PointRoadDetails30mP = Details30;
            obj.PointRoadDetailsImpactP = DetailsImpact;
            obj.RoadImpactPoints60P = RoadImpactPoints60P_;
            obj.RoadImpactPoints30P = RoadImpactPoints30P_;
            obj.RoadImpactPointsImpactP = RoadImpactPointsImpactP_;

            % Set changed flag to 0.
            obj.RoadNetworkChangedMajor = 0;
            obj.RoadNetworkChangedMinor = 0;
        end % function GetRoadsImpacting(obj, varargin)
        
        function CalculatePointTrafficContributions(obj, varargin)
            if obj.NumPoints == 0
                fprintf('CalculatePointTrafficContributions: No points assigned.\n')
                return
            end  
            if obj.RoadNetworkChangedMajor
                fprintf('CalculatePointTrafficContributions called, but RoadNetworkChangedMajor = 1,\nso a road network assesment is required first.\n')
                obj.GetRoadsImpacting
                fprintf('    Done.\n')
            end
            % Set Changed flag to 0.
            obj.RoadNetworkChangedMinor = 0;
            % Get the background O3.
            if numel(obj.PointBackgroundO3) > 1
                UniqueO3 = unique(obj.PointBackgroundO3);
                if numel(UniqueO3) == 1
                    BGO3 = UniqueO3;
                else
                    warning('SRM1Model:CalculatePointTrafficContributions:ManyO3Values', ...
                        ['The background O3 concentration has multiple values, ', ...
                        'perhaps it comes from mapped values. Unfortunately ', ...
                        'this implementation of SRM1 cannot yet deal with mapped ', ...
                        'ozone, so the mean of all values will be taken. (Actually this would be really easy to alter, when needed!)'])
                    BGO3 = mean(obj.PointBackgroundO3);
                end
            else
                BGO3 = obj.PointBackgroundO3;
            end
            % Get the Dispersion factor for each road for each point.
            Distances = obj.PointRoadsDistances;
            Distances(Distances<3.5) = 3.5;
            A = obj.PointRoadDispersionCoefficientsA;
            B = obj.PointRoadDispersionCoefficientsB;
            C = obj.PointRoadDispersionCoefficientsC;
            Al = obj.PointRoadDispersionCoefficientsAlpha;
            Tree = obj.PointRoadTreeFactor;
            DispersionFactor = A.*Distances.^2 + B.*Distances + C;
            DispersionFactorG30 = Al.*Distances.^(-0.747);
            DispersionFactor(Distances>30) = DispersionFactorG30(Distances>30);
            FullFactor = 0.62*DispersionFactor.*Tree*5/obj.AverageWindSpeed;
            % Get the emissions.
            EmPM10 = obj.PointRoadEmissionPM10;
            EmPM25 = obj.PointRoadEmissionPM25;
            EmNOx = obj.PointRoadEmissionNOx;
            EmNO2 = obj.PointRoadEmissionNO2;
            %NitrogenFraction = EmNO2/EmNOx;
            % Calculate the process contributions for each road
            PointConcentrationsPM10 = FullFactor.*EmPM10;
            PointConcentrationsPM25 = FullFactor.*EmPM25;
            PointConcentrationsNOx = FullFactor.*EmNOx;

            % Set nan's to zeros.
            PointConcentrationsPM10(isnan(PointConcentrationsPM10)) = 0;
            PointConcentrationsPM25(isnan(PointConcentrationsPM25)) = 0;
            PointConcentrationsNOx(isnan(PointConcentrationsNOx)) = 0;

            % Do the NO2 conversion.
            CTotalNOx = sum(PointConcentrationsNOx, 2);
            NitrogenFraction = EmNO2./EmNOx;
            NitrogenFraction = NitrogenFraction.*PointConcentrationsNOx;
            NitrogenFraction(isnan(NitrogenFraction)) = 0;
            NitrogenFraction = sum(NitrogenFraction, 2)./CTotalNOx;
            LA = NitrogenFraction.*CTotalNOx;
            LB = obj.ParameterB*BGO3*CTotalNOx.*(1 - NitrogenFraction);
            LC = CTotalNOx.*(1 - NitrogenFraction) + obj.ParameterK;
            PointConcentrationsNO2 = LA + LB./LC;
            PointConcentrationsNO2(CTotalNOx == 0) = 0;
            
            % And sum the others together.
            PointConcentrationsPM10 = sum(PointConcentrationsPM10, 2);
            PointConcentrationsPM25 = sum(PointConcentrationsPM25, 2);
            PointConcentrationsNOx = CTotalNOx;
            TCPs.PM10 = PointConcentrationsPM10;
            TCPs.PM25 = PointConcentrationsPM25;
            TCPs.NOx = PointConcentrationsNOx;
            TCPs.NO2 = PointConcentrationsNO2;
            obj.PointTrafficContributionsP = TCPs;
        end % function CalculatePointTrafficContributions(obj)
        
        function ExportPointConcentrationShapeFile(obj)
            
            NameMuse = 'NotSet';
            % Choose a file name. The first choice will be based on the
            % model save location, if set...
            if ~isequal(obj.FileLocation, 'NoFile')
                % It is set.
                NameMuse = obj.FileLocation;
            elseif ~isequal(obj.RoadNetwork.SourceShapeFile, 'NotSpecified')
                % The second choice is the filename for the shape file that
                % provided the road network.
                NameMuse = obj.RoadNetwork.SourceShapeFile;
            end
            
            if isequal(NameMuse, 'NotSet')
                SuggestPath = '';
                SuggestName = 'ExportedPointConcentrations';
            else
                [pp, ff, ~] = fileparts(NameMuse);
                SuggestPath = [pp, '\'];
                SuggestName = [ff, '_ExportedPointConcentrations'];
            end
            
            SuggestFName = [SuggestPath, SuggestName, '.shp']; FP = 1;
            while exist(SuggestFName, 'file') == 2
                FP = FP + 1;
                SuggestFName = [SuggestPath, SuggestName, sprintf('(%d).shp', FP)];
            end
            
            [FN, PN] = uiputfile(SuggestFName, 'Create new concentration shapefile.');
            if isequal(FN, 0)
                return
            end
            SaveName = [PN, FN];
            Pts = obj.CalculationPoints;
            [NumPts, ~] = size(Pts);
            
            PCPM10s = obj.PointTrafficContributionsPM10;
            PCPM25s = obj.PointTrafficContributionsPM25;
            PCNO2s = obj.PointTrafficContributionsNO2;
            PCNOxs = obj.PointTrafficContributionsNOx;
            BPM10s = obj.PointBackgroundPM10;
            BPM25s = obj.PointBackgroundPM25;
            BNO2s = obj.PointBackgroundNO2;
            BNOxs = obj.PointBackgroundNOx;
            BO3s = obj.PointBackgroundO3;
            wb = waitbar(0, sprintf('Adding feature for calculation point %d of %d.', 1, NumPts), ...
                         'CreateCancelBtn', ...
                         'setappdata(gcbf, ''canceling'',1)');
            setappdata(wb, 'canceling', 0)
            for PtI = 1:NumPts
                if getappdata(wb, 'canceling')
                    delete(wb)
                    return
                end
                waitbar(PtI/NumPts, wb, sprintf('Adding feature for calculation point %d of %d.', PtI, NumPts))
                Pt = struct();
                Pt.X = obj.CalculationPoints(PtI, 1);
                Pt.Y = obj.CalculationPoints(PtI, 2);
                Pt.Geometry = 'point';
                if numel(obj.CalculationPointID)
                    Pt.PointID = obj.CalculationPointID(PtI);
                end
                if numel(obj.CalculationPointType)
                    Pt.Type = obj.CalculationPointType{PtI};
                end
                if numel(obj.CalculationPointStreetName)
                    Pt.StreetName = obj.CalculationPointStreetName{PtI};
                end
                if numel(obj.CalculationPointName)
                    Pt.PointName = obj.CalculationPointName{PtI};
                end
                Pt.PC_PM10 = PCPM10s(PtI);
                Pt.PC_PM25 = PCPM25s(PtI);
                Pt.PC_NO2 = PCNO2s(PtI);
                Pt.PC_NOx = PCNOxs(PtI);
                Pt.BG_PM10 = BPM10s(PtI);
                Pt.BG_PM25 = BPM25s(PtI);
                Pt.BG_NO2 = BNO2s(PtI);
                Pt.BG_NOx = BNOxs(PtI);
                Pt.BG_O3 = BO3s(PtI);
                Pt.TC_PM10 = Pt.PC_PM10 + Pt.BG_PM10;
                Pt.TC_PM25 = Pt.PC_PM25 + Pt.BG_PM25;
                Pt.TC_NOx = Pt.PC_NOx + Pt.BG_NOx;
                Pt.TC_NO2 = Pt.PC_NO2 + Pt.BG_NO2;
                Pt.Distance = obj.PointMinRoadDistances(PtI);
                Pt.NumRoads = obj.PointNumRoadsImpacting(PtI);
                if PtI == 1
                    S = repmat(Pt, NumPts, 1);
                else
                    S(PtI) = Pt;
                end
            end
            waitbar(1, wb, 'Saving file. Please wait a moment...')
            shapewrite(S, SaveName)
            delete(wb)
        end % function ExportPointConcentrationShapeFile(obj)
        
        function val = GetBackground(obj, PPP, Num)
            if ~ismember(PPP, {'O3', 'NO2', 'NOx', 'PM10', 'PM25'})
                error('SRM1Model:GetBackground:WrongPollutant', 'Background pollutant must be one of ''O3'', ''NO2'', ''NOx'', ''PM10'', or ''PM25''.')
            end
            BG = sprintf('Background%sP', PPP);
            %[NumPts, ~] = size(obj.CalculationPoints);
            WrongSizeError = 0;
            if Num == 1
                val = obj.(BG);
            else
                % Multiple calculation points. How many background points
                % do we have?
                NumBG = numel(obj.(BG));
                if NumBG == 1
                    % Just the one! So just one background for everywhere,
                    % create an array of that value of the appropriate
                    % size.
                    val = obj.(BG)*ones(Num, 1);
                elseif NumBG == NumPts
                    % Lots of background points. 
                    %if isequal(size(obj.(BG)), [NumPts, 1])
                    %    val = obj.(BG);
                    %elseif isequal(size(obj.(BG)), [1, NumPts])
                    %    val = obj.(BG)';
                    %else
                    %    WrongSizeError = 1;
                    %end
                    error('SRM1Model:GetBackground:MultipleBackground', 'GetBackground can only deal with one background concentration per pollutant per model.')
                else
                    WrongSizeError = 1;
                end
                if WrongSizeError
                    error('SRM1Model:GetBackground:WrongSize', 'Background %s pollutant has the wrong size. Try reassigning it.', PPP)
                end
            end
        end % function val = GetBackground(obj, PPP, Num)
        
        function AssignBackgroundFromMaps(obj, P, varargin)
            % Assign background PointConcentrations using pollution maps
            % published by the Air Quality Scotland website of Defra. See
            % the documentation for GetBackgroundConcentration for details,
            % including the optional name value pair arguments (of which
            % 'year' is probably the most important).
            % By default, the 'option' parameter will be set to
            % 'ExcludeRoadIn', but this can be set differently in the usual
            % way.
            if ~ismember(P, {'NO2', 'NOx', 'PM10', 'PM25'})
                error('SRM1Model:AssignBackgroundFromMaps:WrongPollutant', 'Background pollutant maps are only available for ''NO2'', ''NOx'', ''PM10'', and ''PM25''.')
            end
            BG = sprintf('Background%sP', P);
            Xs = obj.CalculationPoints(:, 1);
            Ys = obj.CalculationPoints(:, 2);
            % Check to see if an 'option' attribute has been specified.
            OptionSpecified = 0;
            for vi = 1:numel(varargin)
                var = varargin{vi};
                if isequal(var, 'option')
                    OptionSpecified = 1;
                end
            end
            if ~OptionSpecified
                varargin{end+1} = 'option';
                varargin{end+1} = 'ExcludeRoadIn';
            end
            if isequal(P, 'NO2')
                fprintf('Calculating background PointConcentrations for NO2 is more complicated than it is for other pollutants. This may take some time...\n')
                obj.(BG) = GetBackgroundConcentration(Xs, Ys, P, varargin);
            else
                obj.(BG) = GetBackgroundConcentration(Xs, Ys, P, varargin);
            end
        end % function AssignBackgroundFromMaps(obj, P, varargin)
        
        function SetVehicleScaling(obj, varargin)
            VBD = obj.VehicleBreakdown;
            if numel(varargin) == 1
                if isnumeric(varargin{1})
                    % All the same value.
                    for VI = 1:numel(VBD)
                        V = VBD{VI};
                        VS.(V) = varargin{1};
                    end
                    obj.RoadNetwork.VehicleScaling = VS;
                elseif isstruct(varargin{1})
                    try
                        obj.RoadNetwork.VehicleScaling = varargin{1};
                    catch err
                        if isequal(err.identifier, 'SRM1Model:SetVehicleScaling:WrongVehs')
                            VS = obj.VehicleScaling;
                            NewScaling = varargin{1};
                            NewFs = fieldnames(NewScaling);
                            for Fi = 1:numel(NewFs)
                                F = NewFs{Fi};
                                if ~ismember(F, obj.VehicleBreakdown)
                                    error('SRM1:RoadSegment:SetVehicleScaling:WrongVeh', 'Vehicle %s is not a part of the vehicle breakdown of this road segment.', F)
                                end
                                VS.(F) = NewScaling.(F);
                            end
                            obj.RoadNetwork.VehicleScaling = VS;
                        else
                            rethrow(err)
                        end
                    end
                else
                    error('SRM1:RoadSegment:SetVehicleScalingF:SingleNotNumeric', 'If only one input is assigned for SetVehicleScaling, it sould either be a numeric scalar or an appropriate structure.')
                end
            else
                Options = checkArguments(obj.VehicleScaling, varargin);
                obj.RoadNetwork.VehicleScaling = Options;
            end
        end % function SetVehicleScaling(obj, varargin)
        
        function SetPointRoadArrays(obj, Name, Indices, Value)
            if ~ismember(Name, fieldnames(obj.PointRoadDetailsImpactP))
                fieldnames(obj.PointRoadDetailsImpactP)
                error('SRM1Model:SetPointRoadArrays:BadName', 'Field ''%s'' is not recognised.', Name)
            end
            obj.PointRoadDetailsImpactP.(Name)(Indices) = Value;
        end % function SetPointRoadArrays(obj, Name, Indices, Values)
        
        function ChangeRoadClass(obj, RoadIndex)
            % Has it changed?
            DetailNames = {'EmNOx', 'EmNO2', 'EmPM25', 'EmPM10', 'Tree', ...
                'DispAlpha', 'DispC', 'DispB', 'DispA', 'ImpactDistances', ...
                'RoadsCloseButNotImpactingReasons', ...
                'RoadsCloseButNotImpacting', 'RoadsImpacting'};
            
            RoadClasses = {'Wide Canyon', 'Narrow Canyon', 'One Sided Canyon', 'Not A Canyon'};
            OldValue = obj.RoadNetwork.RoadClasses(RoadIndex);
            OldRoad = RoadClasses{OldValue};
            OldImpactDistance = obj.RoadNetwork.ImpactDistances(RoadIndex);
            NewRoad = obj.RoadNetwork.RoadSegments(RoadIndex).RoadClass;
            NewImpactDistance = obj.RoadNetwork.RoadSegments(RoadIndex).ImpactDistance;
            Pts60 = obj.RoadImpactPoints60P(RoadIndex, :); Pts60 = Pts60(isfinite(Pts60));
            if ~isequal(OldRoad, NewRoad)
                fprintf('Road %d changed from class %s to %s.\n', RoadIndex, OldRoad, NewRoad) 
                if isequal(OldImpactDistance, NewImpactDistance)
                    fprintf('    Impact distance is unchanged.\n')
                else
                    if NewImpactDistance == 60
                        fprintf('    Impact distance changed from 30 to 60m.\n')                 
                        NewRoadDetails = obj.PointRoadDetails60mP;
                    elseif NewImpactDistance == 30
                        fprintf('    Impact distance changed from 60 to 30m.\n')
                        NewRoadDetails = obj.PointRoadDetails30mP;
                    else
                        error('Euggggj?')
                    end
                    ImpactDetails = obj.PointRoadDetailsImpactP;
                    for Pt = Pts60
                        RdsImpact = ImpactDetails.RoadsImpacting(Pt, :); RdsImpact = RdsImpact(isfinite(RdsImpact));
                        RdsNew = NewRoadDetails.RoadsImpacting(Pt, :); RdsNew = RdsNew(isfinite(RdsNew));
                        if ~isequal(RdsImpact, RdsNew)
                            RoadIn = [ismember(RoadIndex, RdsImpact), ismember(RoadIndex, RdsNew)];
                            if isequal(RoadIn, [1, 0])
                                fprintf('    Road %d needs to be removed from point %d.\n', RoadIndex, Pt)
                                [~, BlahIndex] = ismember(RoadIndex, ImpactDetails.RoadsImpacting(Pt, :));
                                obj.PointRoadDetailsImpactP.RoadsDistances(Pt, BlahIndex) = nan;
                                [obj.PointRoadDetailsImpactP.RoadsDistances(Pt, :), SortOrder] = sort(obj.PointRoadDetailsImpactP.RoadsDistances(Pt, :));
                                for DNi = 1:numel(DetailNames)
                                    DN = DetailNames{DNi};
                                    obj.PointRoadDetailsImpactP.(DN)(Pt, BlahIndex) = nan;
                                    obj.PointRoadDetailsImpactP.(DN)(Pt, :) = obj.PointRoadDetailsImpactP.(DN)(Pt, SortOrder);
                                end
                                obj.PointRoadDetailsImpactP.NumRoadsImpacting(Pt) = sum(isfinite(obj.PointRoadDetailsImpactP.RoadsImpacting(Pt, :)));
                                obj.PointRoadDetailsImpactP.ClosestRoadDistances(Pt) = obj.PointRoadDetailsImpactP.RoadsDistances(Pt, 1);
                            elseif isequal(RoadIn, [0, 1])
                                fprintf('    Road %d needs to be added to point %d.\n', RoadIndex, Pt)
                                [~, BlahIndex] = ismember(RoadIndex, NewRoadDetails.RoadsImpacting(Pt, :));
                                obj.PointRoadDetailsImpactP.RoadsDistances(Pt, end) = NewRoadDetails.RoadsDistances(Pt, BlahIndex);
                                [obj.PointRoadDetailsImpactP.RoadsDistances(Pt, :), SortOrder] = sort(obj.PointRoadDetailsImpactP.RoadsDistances(Pt, :));
                                for DNi = 1:numel(DetailNames)
                                    DN = DetailNames{DNi};
                                    obj.PointRoadDetailsImpactP.(DN)(Pt, end) = NewRoadDetails.(DN)(Pt, BlahIndex);
                                    obj.PointRoadDetailsImpactP.(DN)(Pt, :) = obj.PointRoadDetailsImpactP.(DN)(Pt, SortOrder);
                                end
                                obj.PointRoadDetailsImpactP.NumRoadsImpacting(Pt) = sum(isfinite(obj.PointRoadDetailsImpactP.RoadsImpacting(Pt, :)));
                                obj.PointRoadDetailsImpactP.ClosestRoadDistances(Pt) = obj.PointRoadDetailsImpactP.RoadsDistances(Pt, 1);
                            end
                        end
                    end
                end
            end
        end % function ChangeRoadClass(obj, RoadIndex, Value)
        
        function SaveModel(obj)
            % Create a filename, if one is not already set.
            if isequal(obj.FileLocation, 'NoFile')
                obj.SaveModelAs
            else
                % Check that it is writeable.
                if ~CheckWriteable(obj.FileLocation, 'Type', '.srm1')
                    [~, b] = CheckWriteable(obj.FileLocation, 'Type', '.srm1');
                    error('SRM1Model:Save:CannotWrite', 'Cannot save model because ''%s''.', b)
                end
                % Save as a matlab .mat file.
                save(obj.FileLocation, 'obj', '-mat')
            end
        end % function SaveModel(obj)
        
        function SaveModelAs(obj)
            
            % Create a filename.
            Num = 1;
            if isequal(obj.FileLocation, 'NoFile');
                NN = 'UntitledModel';
                FF = [pwd, '\'];
            else
                [FF, NN, ~] = fileparts(obj.FileLocation);
                FF = [FF, '\'];
                if isequal(NN(end), ')')
                    PS = strfind(NN, '(');
                    if PS
                        PS = PS(end);
                        Num = str2double(NN(PS+1: end-1));
                        if isfinite(Num)
                            Num = Num+1;
                            NN = NN(1:PS-1);
                        end
                    end
                end
            end
            FileSuggest = sprintf('%s%s(%d).srm1', FF, NN, Num);
            while exist(FileSuggest, 'file') == 2
                Num = Num+1;
                FileSuggest = sprintf('%s%s(%d).srm1', FF, NN, Num);
            end
            [FN, PN] = uiputfile(FileSuggest, 'Save model to...');
            if isequal(FN, 0)
                return
            end
            obj.FileLocation = [PN,FN];
            obj.SaveModel
        end % function SaveModelAs(obj)
        
        function PlotPoint(obj, PointID)
            figure
            axis equal
            hold on
            X = obj.CalculationPoints(PointID, 1);
            Y = obj.CalculationPoints(PointID, 2);
            
            ReasonsStrings = {'A. Road is continuation of closer road', ...
                'B. Road is continuation of closer road', ...
                'C. No intersection, the road is a canyon', ...
                'D. No intersection, point is in a canyon.', ...
                'E. No traffic on this road.'};
            RoadsNotImpacting = obj.PointRoadsCloseButNotImpacting(PointID, :);
            RoadsNotImpacting = RoadsNotImpacting(isfinite(RoadsNotImpacting));
            Reasons = obj.PointRoadsCloseButNotImpactingReasons(PointID, :);
            plot(X, Y, 'X')
            for RDIi = 1:numel(RoadsNotImpacting)
                RDI = RoadsNotImpacting(RDIi);
                Rd = obj.RoadNetwork.RoadSegments(RDI);
                Vs = Rd.Vertices;
                plot(Vs(:, 1), Vs(:, 2), 'LineWidth', 0.5, 'Color', [0.5, 0.5, 0.5], 'marker', 'o')
                text(mean(Vs(:,1)), mean(Vs(:,2)) , sprintf('%d', RDI), 'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'k')
                fprintf('    Road %d: %s.\n', RDI, ReasonsStrings{Reasons(RDIi)});
            end
            RoadsImpacting = obj.PointRoadsImpacting(PointID, :);
            RoadsImpacting = RoadsImpacting(isfinite(RoadsImpacting));
            Cls = {'b', 'r', 'm', 'g', 'c'};
            for RDIi = 1:numel(RoadsImpacting)
                RDI = RoadsImpacting(RDIi);
                Rd = obj.RoadNetwork.RoadSegments(RDI);
                Vs = Rd.Vertices;
                Cl = 1+mod(RDIi-1, 5);
                plot(Vs(:, 1), Vs(:, 2), 'LineWidth', 1.5, 'Color', Cls{Cl}, 'marker', 'o')
                text(mean(Vs(:,1)), mean(Vs(:,2)) , sprintf('%d', RDI), 'Color', Cls{Cl}, 'BackgroundColor', 'w', 'EdgeColor', 'k')
            end
            title(sprintf('Point %d: %d roads impacting', PointID, numel(RoadsImpacting)))
        end % function PlotPoint(obj, PointID)
        
        function EmissionFactorControl(obj)
            SRM1.EmissionFactorControlDialogue('ModelObject', obj)
        end % function EmissionFactorControl(obj)
    end % methods
    
    methods (Static)
        function NewObj = OpenFile(varargin)
            if nargin == 1
                FileLocation_ = varargin{1};
            else
                [FN, PN] = uigetfile('*.srm1', 'Open model...');
                if isequal(FN, 0)
                    NewObj = SRM1Model.empty;
                    return
                else
                    FileLocation_ = [PN, FN];
                end
            end
            NewObj = load(FileLocation_, 'obj', '-mat');
            NewObj = NewObj.obj;
        end % function NewObj = OpenFile(varargin)
    end % methods (Static)
end