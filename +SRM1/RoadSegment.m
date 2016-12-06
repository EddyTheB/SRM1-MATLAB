classdef RoadSegment < handle
    % RoadSegment
    %   A RoadSegment class for use by the SRM1 Model. It contains the
    %   properties necceasry to describe the road segment (vertices, road
    %   width, canyon type, etc), plus the traffic (vehicle counts, speed,
    %   stagnation factors, etc.).
    %
    %   It also contains methods and dependent properties which give
    %   emission quantities and concentrations at a set distance from the
    %   road centre.
    %
    %   Commenting is a work in progress...
    %
    %   Designed to be used by SRM1Model.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   RoadSegment.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 24 2016 11:06:36  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties
        ParentRoadNetwork@SRM1.RoadNetwork
        RoadID
        RoadName = 'Not Assigned'
        
        PollutantsAllowed  % All pollutants, vehicle classes, and speed classes 
        VehClassesAllowed  % available for this road segment, based on the emission
        SpeedClassesAllowed% factors being used.
        SpeedClassCorrect
        VehicleBreakdown
        %TunnelConnection = nan
    end % properties
    
    properties (Dependent)
        % Properties marked A, or B below will, if set, change the
        % ChangesMadeMajor and ChangesMadeMinor properties of the parent
        % road network, if set. Those marked C are genuine dependent
        % properties with no set method.
        RoadClass         % A.

        ImpactDistance    % C*. The maximum distance that the road will have an impact at. Depends on RoadClass
        DispersionCoefficients % C. Depends on RoadClass, and on DispersionCoefficientsAll.
        Vertices          % A.
        NumVertices       % C. The number of vertices. Depends on Vertices.
        length            % C. The length of the road. Depends on Vertices.
        BoundingBox       % C*. [min(X), min(Y); max(X), max(Y)]. Depends on Vertices.
        ImpactBoundingBox % C*. Depends on ImpactDistance and on BoundingBox.
                          % * means these properties will be assigned to
                          % a private property everytime Vertices or RoadClass is set.
        Speed             % B. To use the dutch emission factors, SpeedClass
        Stagnation        % B  and Stagnation are both required. To use NAEI
        SpeedClass        % B  factors only Speed is required.
        TreeFactor        % B        
        VehicleScaling    % B
        VehicleCounts     % B
        VehicleCountsScaled % C. Depends on VehicleScaling and on VehicleCounts.
        TrafficTotal      % C. Depends on VehicleCounts.
        TrafficTotalScaled% C. Depends on VehicleCountsScaled.
        EmissionFactors   % B.
        Emissions         % C. Depends on EmissionFactors Speed, SpeedClass, Stagnation. and VehicleCountsScaled
        % The following properties are used to calculate the contribution
        % of traffic on this road to concentrations at a set distance from
        % the road centre.
        RoadWidth
        CalculationDistanceMode
        CalculationDistance
        CalculationDistanceTotal
        BackgroundO3
        WindSpeed
        ParameterB
        ParameterK
        TrafficContributions
        TrafficContributionsPM10
        TrafficContributionsPM25
        TrafficContributionsNO2
        TrafficContributionsNOx
    end % properties (Dependent)
    
    properties (SetAccess = private, GetAccess = private)
        RoadClassP = 'NotSet'
        VerticesP
        ImpactDistanceP
        BoundingBoxP
        ImpactBoundingBoxP   
        
        EmissionsP
        SpeedP = nan
        SpeedClassP = 'NotSet'
        StagnationP = 0
        TreeFactorP
        VehicleScalingP
        VehicleCountsP
        VehicleCountsScaledP = struct.empty
        EmissionFactorsP
        
        RoadWidthP = 8;
        CalculationDistanceModeP = 'Road Centre'
        CalculationDistanceP = 5
        
        BackgroundO3P = 40
        WindSpeedP = 4
        ParameterBP = 0.6
        ParameterKP = 100
        TrafficContributionsP = struct.empty
        EmissionFactorYearP
    end
    
    properties (SetAccess = private)
        FactorType
    end % properties (SetAccess = private)
    
    properties (Hidden)
        DispersionCoefficientsAll
        NAEIVehMixes = {'PCycle', 'MCycle', 'Car', 'Bus', 'LGV', 'RHGV_2X', 'RHGV_3X', 'RHGV_4X', 'AHGV_34X', 'AHGV_5X', 'AHGV_6X'};
        Creating = 0
        EmissionsBreakdown
        CalculationDistanceModeAllowedValues = {'Road Edge', 'Road Centre'}
    end % properties (Hidden)
    
    properties (Dependent, Hidden)
        EmissionFactorYear
    end % properties (Dependent, Hidden)

    methods
        % Constructor
        function obj = RoadSegment(varargin)
            % Now get the input arguments.
            obj.Creating = 1;
            Options = struct('Attributes', 'NotSet', 'Number', NaN, 'Parent', 'NotSet', 'EmissionFactors', 'NotSet', 'DispersionCoefficients', 'Default', 'EmissionFactorYear', 'NotSet');
            Options = checkArguments(Options, varargin);
            GotEmissionFactors = 0;
            if ~isequal('EmissionFactorYear', 'NotSet')
                [obj.EmissionFactorYearP, ~] = datevec(now);
            else
                obj.EmissionFactorYearP = Options.EmissionFactorYear;
            end
            if ~isequal(Options.Parent, 'NotSet')
                % A parent RoadNetwork has been set.
                obj.ParentRoadNetwork = Options.Parent;
                EmissionFacts = obj.ParentRoadNetwork.EmissionFactors;
                GotEmissionFactors = 1;
            elseif ~isequal(Options.EmissionFactors, 'NotSet')
                EmissionFacts = Options.EmissionFactors;
                GotEmissionFactors = 1;
            end
            if ~isequal(Options.Attributes, 'NotSet')
                % Attributes have been set. These are probably the fields
                % from a shape file for the roads.
                AttributeNames = fieldnames(Options.Attributes);
                % Vertices
                Vs = [Options.Attributes.X', Options.Attributes.Y'];
                if isequal(isnan(Vs(end, :)), [1, 1])
                    Vs = Vs(1:end-1, :);
                end
                obj.Vertices = Vs;
                % Road Type Parameter
                RoadTypePossibilities = {'Road_Type', 'RoadType', 'Road_Class', 'RoadClass'}; GotRTP = 0;
                for RTPi = 1:numel(RoadTypePossibilities)
                    RTP = RoadTypePossibilities{RTPi};
                    if ismember(RTP, AttributeNames)
                        obj.RoadClass = Options.Attributes.(RTP);
                        GotRTP = 1;
                        break
                    end
                end
                if ~GotRTP
                    error('SRM1:RoadSegment:NoRoadType', 'Road segment has no property ''Road_Type''.')
                end
                % Speed Class Parameter
                GotSPEEDCLASS = 0;
                SpeedClassPossibilities = {'Speed_Clas', 'SpeedClass', 'Speed_Type', 'SpeedType'};
                for SCPi = 1:numel(SpeedClassPossibilities)
                    SCP = SpeedClassPossibilities{SCPi};
                    if ismember(SCP, AttributeNames)
                        obj.SpeedClass = Options.Attributes.(SCP);
                        GotSPEEDCLASS = 1;
                        break
                    end
                end
                % Width Parameter
                WidthPossibilities = {'WIDTH', 'RoadWidth', 'Width'};
                for WPi = 1:numel(WidthPossibilities)
                    WP = WidthPossibilities{WPi};
                    if ismember(WP, AttributeNames)
                        obj.RoadWidthP = Options.Attributes.(WP);
                        break
                    end
                end
                % Speed Parameter
                GotSPEED = 0;
                SpeedPossibilities = {'Speed', 'SPEED'};
                for SPi = 1:numel(SpeedPossibilities)
                    SP = SpeedPossibilities{SPi};
                    if ismember(SP, AttributeNames)
                        obj.SpeedP = Options.Attributes.(SP);
                        GotSPEED = 1;
                        break
                    end
                end
                % Stagnation
                GotSTAGNATION = 0;
                if ismember('Stagnation', AttributeNames)
                    obj.StagnationP = Options.Attributes.Stagnation/100;
                    GotSTAGNATION = 1;
                end
                GotSPEEDCLASS = GotSPEEDCLASS && GotSTAGNATION;
                if ~GotSPEEDCLASS && ~GotSPEED
                    error('SRM1:RoadSegment:NoSpeed', 'Road segment has no property ''SpeedClass'', or ''Speed'', one or both is required.')
                end                
                if GotEmissionFactors
                    obj.EmissionFactors = EmissionFacts;
                else
                    if GotSPEED
                        fprintf('No emission factors specified, using NAEI factors.\n')
                        obj.EmissionFactors = EmissionFactorNAEI();
                    else     %if obj.GotSPEEDCLASS
                        fprintf('No emission factors specified, using Dutch factors.\n')
                        obj.EmissionFactors = EmissionFactorDutch();
                    end
                end
                
                % Tree factor parameter
                TreeFactorPossibilities = {'Tree_Facto', 'TreeFactor', 'TREES'}; GotTFP = 0;
                for TFPi = 1:numel(TreeFactorPossibilities)
                    TFP = TreeFactorPossibilities{TFPi};
                    if ismember(TFP, AttributeNames)
                        obj.TreeFactorP = Options.Attributes.(TFP);
                        GotTFP = 1;
                        break
                    end
                end
                if ~GotTFP
                    [~, lwb] = lastwarn;
                    if ~isequal(lwb, 'SRM1:RoadSegment:NoTreeFactor')
                        warning('SRM1:RoadSegment:NoTreeFactor', 'Road segment has no property ''TreeFactor''; the value will be set to 1. This warning may be called repeatedly but will be suppressed.')
                    end
                    obj.TreeFactor = 1;
                end
                
                if isequal(Options.DispersionCoefficients, 'Default')
                    [~, ~, ~, ~, obj.DispersionCoefficientsAll] = SRM1.GetDispersionCoefficients('Narrow Canyon');
                else
                    obj.DispersionCoefficientsAll = Options.DispersionCoefficients;
                end
                    
                % Get the vehicle counts.
                VehicleCounts_ = struct;
                for Vi = 1:numel(obj.NAEIVehMixes)
                    V = obj.NAEIVehMixes{Vi};
                    VOptions = {V, lower(V), upper(V)};
                    Got = 0;
                    for VOi = 1:numel(VOptions)
                        VO = VOptions{VOi};
                        if ismember(VO, fieldnames(Options.Attributes))
                            Got = 1;
                            VehicleCounts_.(V) = Options.Attributes.(VO);
                            break
                        end
                    end
                    if ~Got
                        if ~isequal(V, 'PCycle')
                            % No emissions from PCycle anyway.
                            warning('Missing field for vehicle class ''%s''.', V)
                        end
                    end
                end
                VehicleBreakdown_ = fieldnames(VehicleCounts_);

                %% Vehicle Scaling
                for Vi = 1:numel(VehicleBreakdown_)
                    VS.(VehicleBreakdown_{Vi}) = 1;
                end
                obj.VehicleCountsP = VehicleCounts_;
                obj.VehicleBreakdown = VehicleBreakdown_;
                obj.VehicleScalingP = VS; % Wally
            end
            if ~isnan(Options.Number)
                obj.RoadID = Options.Number;
            end
            obj.Creating = 0;
            obj.ScaleVehicleCounts
            obj.SetParentChangesMajor()
        end % function obj = RoadSegment

        
        %% Getters
        function val = get.RoadClass(obj)
            val = obj.RoadClassP;
        end % function val = get.RoadClass(obj)
            
        function val = get.ImpactDistance(obj)
            val = obj.ImpactDistanceP;
        end % function val = get.ImpactDistance(obj)
        
        function val = get.DispersionCoefficients(obj)
            val = obj.DispersionCoefficientsAll.(strrep(obj.RoadClass, ' ', ''));
        end % function val = get.DispersionCoefficients(obj)
        
        function val = get.Vertices(obj)
            val = obj.VerticesP;
        end % function val = get.Vertices(obj)
        
        function val = get.NumVertices(obj)
            [val, ~] = size(obj.Vertices);
        end % function val = get.NumVertices(obj)
        
        function val = get.length(obj)
            if obj.NumVertices < 2
                val = 0;
            else
                V = obj.Vertices;
                Dist = 0;
                for ki = 2:obj.NumVertices
                    Dist = Dist + ((V(ki, 1) - V(ki-1, 1))^2 + (V(ki, 2) - V(ki-1, 2))^2  )^0.5;
                end
                val = Dist;
            end
        end % function val = get.length(obj)
        
        function val = get.BoundingBox(obj)
            val = obj.BoundingBoxP;
        end % function val = get.BoundingBox(obj)
        
        function val = get.ImpactBoundingBox(obj)
            val = obj.ImpactBoundingBoxP;
        end % function val = get.ImpactBoundingBox(obj)
        
        function val = get.Speed(obj)
            val = obj.SpeedP;
        end % function val = get.Speed(obj)
        
        function val = get.SpeedClass(obj)
            val = obj.SpeedClassP;
        end % function val = get.SpeedClass(obj)
        
        function val = get.Stagnation(obj)
            val = obj.StagnationP;
        end % function val = get.Stagnation(obj)
        
        function val = get.TreeFactor(obj)
            val = obj.TreeFactorP;
        end % function val = get.TreeClass(obj)
        
        %function val = get.VehicleBreakdown(obj)
        %    val = obj.PotentialVehMixes.(obj.VehicleBreakdownName);
        %end % function val = get.VehicleBreakdown(obj)
        
        function val = get.VehicleScaling(obj)
            val = obj.VehicleScalingP;
        end % function val = get.VehicleScaling(obj)
        
        function val = get.VehicleCounts(obj)
            val = obj.VehicleCountsP;
        end % function val = get.VehicleCounts(obj)
        
        function val = get.VehicleCountsScaled(obj)
            if isempty(obj.VehicleCountsScaledP)
                obj.ScaleVehicleCounts
            end
            val = obj.VehicleCountsScaledP;
        end % function val = get.VehicleCountsScaled(obj)
            
        function val = get.TrafficTotal(obj)
           TT = 0;
           for Vi = 1:numel(obj.VehicleBreakdown)
               VV = obj.VehicleBreakdown{Vi};
               CC = obj.VehicleCounts.(VV);
               TT = TT + CC;
           end
           val = TT;
        end % function val = get.TrafficTotal(obj)
        
        function val = get.TrafficTotalScaled(obj)
           TT = 0;
           for Vi = 1:numel(obj.VehicleBreakdown)
               VV = obj.VehicleBreakdown{Vi};
               CC = obj.VehicleCountsScaled.(VV);
               TT = TT + CC;
           end
           val = TT;
        end % function val = get.TrafficTotal(obj)
        
        function val = get.EmissionFactors(obj)
            
            %obj.ParentRoadNetwork.ModelObject.EmissionFactors
            %obj.ParentRoadNetwork.EmissionFactors
            %obj.EmissionFactorsP
            
            val = obj.EmissionFactorsP;
        end % function val = get.EmissionFactors(obj)
        
        function val = get.Emissions(obj)
            Ems = struct;
            for PI = 1:numel(obj.PollutantsAllowed)
                P = obj.PollutantsAllowed{PI};
                EE = obj.Emit_Single(P, obj.SpeedClassCorrect);
                ES = obj.Emit_Single(P, obj.EmissionFactors.StagnantSpeedClass);
                EE = (1000/(24*3600))*(1 - obj.Stagnation) * EE;
                ES = (1000/(24*3600))*obj.Stagnation * ES;
                obj.EmissionsBreakdown.(P) = EE + ES;
                Ems.(P) = sum(EE + ES);
            end
            val = Ems;
        end % function val = get.Emissions(obj)        
                
        function val = get.EmissionFactorYear(obj)
            val = obj.EmissionFactorYearP;
        end % function val = get.EmissionFactorYear(obj)
        
        function val = get.RoadWidth(obj)
            val = obj.RoadWidthP;
        end % function val = get.RoadWidth(obj)
        
        function val = get.CalculationDistanceMode(obj)
             % First check, is a RoadNetwork object defined? 
            if ~isempty(obj.ParentRoadNetwork)
                % It is. In that case use the value from the road network.
                if ~isequal(obj.CalculationDistanceModeP, obj.ParentRoadNetwork.CalculationDistanceMode)
                    obj.CalculationDistanceModeP = obj.ParentRoadNetwork.CalculationDistanceMode;
                    obj.TrafficContributionsP = struct.empty;
                end
            end
            val = obj.CalculationDistanceModeP;
        end % function val = get.CalculationDistanceMode(obj)
        
        function val = get.CalculationDistance(obj)
            % First check, is a RoadNetwork object defined? 
            if ~isempty(obj.ParentRoadNetwork)
                % It is. In that case use the value from the road network.
                if ~isequal(obj.CalculationDistanceP, obj.ParentRoadNetwork.CalculationDistance)
                    obj.CalculationDistanceP = obj.ParentRoadNetwork.CalculationDistance;
                    obj.TrafficContributionsP = struct.empty;
                end
            end
            val = obj.CalculationDistanceP; 
        end % function val = get.CalculationDistance(obj)
        
        function val = get.CalculationDistanceTotal(obj)
            switch obj.CalculationDistanceMode
                case 'Road Edge'
                    val = obj.CalculationDistance + obj.RoadWidth/2;
                case 'Road Centre'
                    val = obj.CalculationDistance;
                otherwise
                    error('Must be ''Road Centre'' or ''Road Edge''.')
            end
        end % function val = get.CalculationDistanceTotal(obj)
        
        function val = get.WindSpeed(obj)
            VV = obj.WindSpeedP;
            % Is a road network and model object specified?
            if ~isempty(obj.ParentRoadNetwork)
                % A road network is.
                if ~isempty(obj.ParentRoadNetwork.ModelObject)
                    % And a model object is too.
                    VV = obj.ParentRoadNetwork.ModelObject.AverageWindSpeed;
                    obj.TrafficContributionsP = struct.empty;
                end
            end
            val = VV;
        end % function val = get.WindSpeed(obj)
        
        function val = get.BackgroundO3(obj)
            VV = obj.BackgroundO3P;
            % Is a road network and model object specified?
            if ~isempty(obj.ParentRoadNetwork)
                % A road network is.
                if ~isempty(obj.ParentRoadNetwork.ModelObject)
                    % And a model object is too.
                    VV = obj.ParentRoadNetwork.ModelObject.BackgroundO3;
                    if numel(VV) ~= 1
                        VV = VV(obj.RoadID);
                    end
                end
            end
            val = VV;
        end % function val = get.BackgroundO3(obj)
        
        function val = get.ParameterB(obj)
            VV = obj.ParameterBP;
            % Is a road network and model object specified?
            if ~isempty(obj.ParentRoadNetwork)
                % A road network is.
                if ~isempty(obj.ParentRoadNetwork.ModelObject)
                    % And a model object is too.
                    VV = obj.ParentRoadNetwork.ModelObject.ParameterB;
                end
            end
            val = VV;
        end % function val = get.ParameterB(obj)
        
        function val = get.ParameterK(obj)
            VV = obj.ParameterKP;
            % Is a road network and model object specified?
            if ~isempty(obj.ParentRoadNetwork)
                % A road network is.
                if ~isempty(obj.ParentRoadNetwork.ModelObject)
                    % And a model object is too.
                    VV = obj.ParentRoadNetwork.ModelObject.ParameterK;
                end
            end
            val = VV;
        end % function val = get.ParameterK(obj)
        
        function val = get.TrafficContributions(obj)
            obj.CalculationDistanceTotal; % "Getting" this will reset TrafficContributions, if distance hase been changed.
            obj.WindSpeed;
            if isempty(obj.TrafficContributionsP)
                obj.GetTrafficContributions;
            end
            val = obj.TrafficContributionsP;
        end % function val = get.TrafficContributions(obj)
        
        function val = get.TrafficContributionsPM10(obj)
            val = obj.TrafficContributions.PM10;
        end % function val = get.TrafficContributionsPM10(obj)
        
        function val = get.TrafficContributionsPM25(obj)
            val = obj.TrafficContributions.PM25;
        end % function val = get.TrafficContributionsPM25(obj)
                
        function val = get.TrafficContributionsNO2(obj)
            val = obj.TrafficContributions.NO2;
        end % function val = get.TrafficContributionsNO2(obj)
        
        function val = get.TrafficContributionsNOx(obj)
            val = obj.TrafficContributions.NOx;
        end % function val = get.TrafficContributionsNOx(obj)
        
        %% Setters
        function set.RoadClass(obj, val)
            if ~isequal(val, obj.RoadClassP)
                obj.RoadClassP = val;
                obj.SetBoundingBox
                obj.SetParentChangesMinor('RoadClass')
            end
        end % function set.RoadClass(obj, val)
        
        function set.Vertices(obj, val)
            if ~isequal(val, obj.VerticesP)
                obj.VerticesP = val;
                obj.SetBoundingBox
                obj.SetParentChangesMajor()
            end
        end % function set.Vertices(obj, val)
        
        function set.Speed(obj, val)
            if ~isequal(obj.SpeedP, val)
                obj.SpeedP = val;
                obj.SetParentChangesMinor('Emissions')
            end
        end % function set.Speed(obj, val)
        
        function set.Stagnation(obj, val)
            if ~IsBetween(val,  0, 1)
                error('SRM1:RoadSegment:SetStagnation:OutOfRange', 'Stagnation factor should be between 0 and 1.')
            end
            if ~isequal(obj.StagnationP, val)
                obj.StagnationP = val;
                obj.SetParentChangesMinor('Emissions')
            end
        end % function set.Stagnation(obj, val)
        
        function set.SpeedClass(obj, val)
            if ~isequal(obj.SpeedClassP, val)
                switch val
                    case {'Large Road', 'Large Roads', 'LargeRoad'}
                        VV = 'LargeRoad';
                    case {'Normal City Traffic', 'Normal'}
                        VV = 'Normal';
                    case {'Smooth City Traffic', 'Smooth'}
                        VV = 'Smooth';
                    case {'Stagnant Traffic', 'Stagnated', 'Stagnant'}
                        VV = 'Stagnated';
                    otherwise
                        % Ought to add something for stagnated traffic.
                        error('SRM1:RoadSegment:SetSpeedClass', 'Unknown speed class %s.', val)
                end
                obj.SpeedClassP = VV;
                obj.SetParentChangesMinor('Emissions')
            end
        end % function set.SpeedClass(obj, val)
        
        function set.TreeFactor(obj, val)
            if ~isequal(obj.TreeFactorP, val)
                obj.TreeFactorP = val;
                obj.SetParentChangesMinor('Tree')
            end
        end % function set.TreeFactor(obj, val)
        
        function set.VehicleScaling(obj, val)
            if ~isequal(val, obj.VehicleScalingP)
                if ~isstruct(val)
                    error('SRM1Model:SetVehicleScaling:WrongClass', 'VehicleScaling should be of class struct.')
                end
                if ~isequal(fieldnames(val), obj.VehicleBreakdown) && ~isequal(fieldnames(val), obj.VehicleBreakdown')
                    error('SRM1Model:SetVehicleScaling:WrongVehs', 'The fieldnames of VehicleScaling must be the contents of VehicleBreakdown (and in the same order).')
                end
                obj.VehicleScalingP = val;
                obj.VehicleCountsScaledP = [];
                %TTT = obj.TrafficTotalScaled;
                obj.SetParentChangesMinor('Emissions')
                obj.SetParentChangesMinor('TrafficTotalsScaled')
            end
        end % function set.VehicleScaling(obj, val)         
        
        function set.EmissionFactors(obj, val)
            if ~isequal(val, obj.EmissionFactorsP)
                % First, ensure that if a ParentRoadNetwork is set, that
                % val is the same value as the emission factors for it.
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network exists.
                    if ~isequal(val, obj.ParentRoadNetwork.EmissionFactors)
                        % It's not the same.
                        error('SRM1:RoadSegment:SetEmissionFactors:NotMatchNetwork', 'Specified emission factors do not agree with those for the parent road netwrok.')
                    end
                end
                % Ok, the road network, if any, has allowed us to proceed.
                obj.PollutantsAllowed = val.Pollutants;
                obj.VehClassesAllowed = val.VehicleClasses;
                obj.SpeedClassesAllowed = val.SpeedClasses;
                SpeedC = sprintf('S_%03d', obj.Speed);
                if ismember(obj.SpeedClass, obj.SpeedClassesAllowed)
                    obj.SpeedClassCorrect = obj.SpeedClass;
                elseif ismember(SpeedC, obj.SpeedClassesAllowed)
                    obj.SpeedClassCorrect = SpeedC;
                else
                    error('The emission factors cannot deal with a speedclass ''%s'' or a speed ''%.*f''', obj.SpeedClass, DecPlaces(obj.Speed), obj.Speed)
                end
                obj.EmissionFactorsP = val;
                obj.SetParentChangesMinor('Emissions')
            end
        end % function set.EmissionFactors(obj, val)
        
        function set.EmissionFactorYear(obj, val)
            if ~isequal(val, obj.EmissionFactorYearP)
                % First, ensure that if a ParentRoadNetwork is set, that
                % val is the same value as the emission factors for it.
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network exists.
                    if ~isequal(val, obj.ParentRoadNetwork.EmissionFactorYear)
                        % It's not the same.
                        error('SRM1:RoadSegment:SetEmissionFactorYear:NotMatchNetwork', 'Specified EmissionFactorYear does not agree with that for the parent road netwrok.')
                    end
                end
                % Ok, the road network, if any, has allowed us to proceed.
                %obj.PollutantsAllowed = val.Pollutants;
                %obj.VehClassesAllowed = val.VehicleClasses;
                %obj.SpeedClassesAllowed = val.SpeedClasses;
                %SpeedC = sprintf('S_%03d', obj.Speed);
                %if ismember(obj.SpeedClass, obj.SpeedClassesAllowed)
                %    obj.SpeedClassCorrect = obj.SpeedClass;
                %elseif ismember(SpeedC, obj.SpeedClassesAllowed)
                %    obj.SpeedClassCorrect = SpeedC;
                %else
                %    error('The emission factors cannot deal with a speedclass ''%s'' or a speed ''%.*f''', obj.SpeedClass, DecPlaces(obj.Speed), obj.Speed)
                %end
                %obj.EmissionFactorsP = val;
                obj.EmissionFactorYearP = val;
                obj.SetParentChangesMinor('Emissions')
            end
        end % function set.EmissionFactorYear(obj, val)
        
        function set.RoadWidth(obj, val)
            if ~isequal(val, obj.RoadWidthP)
                obj.RoadWidthP = val;
                obj.TrafficContributionsP = struct.empty;
            end
        end % function set.RoadWidth(obj, val)
        
        function set.CalculationDistanceMode(obj, val)
            % First check, is a RoadNetwork object defined?
            if ~isempty(obj.ParentRoadNetwork)
                % It is. Well is the calculation distance mode of that object the
                % same as is being specified? If so, then it might be that
                % object doing the setting.
                if ~isequal(val, obj.ParentRoadNetwork.CalculationDistanceMode)
                    error('SRM1Model:RoadSegment:SetCalculationDistanceMode:NetworkSet', 'CalculationDistanceMode should be set in the road segment''s parent RoadNetwork object.')
                end
            end
            % And check that the number is not negative.
            if ~ismember(val, app.CalculationDistanceModeAllowedValues)
                error('SRM1Model:RoadNetwork:SetCalculationDistanceMode:BadValue', 'CalculationDistanceMode must be one of either ''%s'' or ''%s''.', app.CalculationDistanceModeAllowedValues{1}, app.CalculationDistanceModeAllowedValues{2})
            end
            obj.CalculationDistanceModeP = val;
            obj.TrafficContributionsP = struct.empty;
        end % function set.CalculationDistanceMode(obj, val)
        
        function set.CalculationDistance(obj, val)
            % First check, is a RoadNetwork object defined?
            if ~isempty(obj.ParentRoadNetwork)
                % It is. Well is the calculation distance of that object the
                % same as is being specified? If so, then it might be that
                % object doing the setting.
                if ~isequal(val, obj.ParentRoadNetwork.CalculationDistance)
                    error('SRM1Model:RoadSegment:SetCalculationDistance:NetworkSet', 'CalculationDistance should be set in the road segment''s parent RoadNetwork object.')
                end
            end
            % And check that the number is not negative.
            if val < 0
                error('SRM1Model:RoadNetwork:SetCalculationDistance:NegativeNumber', 'CalculationDistance must be greater or equal to zero.')
            end
            obj.CalculationDistanceP = val;
            obj.TrafficContributionsP = struct.empty;
        end % function set.CalculationDistance(obj, val)
        
        function set.BackgroundO3(obj, val)
            if ~isequal(obj.BackgroundO3P, val)
                % Is a road network and model object specified?
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network is.
                    if ~isempty(obj.ParentRoadNetwork.ModelObject)
                        % And a model object is too.
                        error('SRM1:RoadSegment:SetBackgroundO3', 'The BackgroundO3 property of this road segment is controlled by it''s parent SRM1Model object.')
                    end
                end
                obj.BackgroundO3P = val;
                obj.TrafficContributionsP = struct.empty;
            end
        end % set.BackgroundO3(obj, val)
        
        function set.WindSpeed(obj, val)
            if ~isequal(obj.WindSpeedP, val)
                % Is a road network and model object specified?
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network is.
                    if ~isempty(obj.ParentRoadNetwork.ModelObject)
                        % And a model object is too.
                        error('SRM1:RoadSegment:SetWindSpeed', 'The WindSpeed property of this road segment is controlled by it''s parent SRM1Model object.')
                    end
                end
                obj.WindSpeedP = val;
                obj.TrafficContributionsP = struct.empty;
            end
        end % function set.WindSpeed(obj, val)
        
        function set.ParameterB(obj, val)
            if ~isequal(obj.ParameterBP, val)
                % Is a road network and model object specified?
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network is.
                    if ~isempty(obj.ParentRoadNetwork.ModelObject)
                        % And a model object is too.
                        error('SRM1:RoadSegment:SetParameterB', 'The ParameterB property of this road segment is controlled by it''s parent SRM1Model object.')
                    end
                end
                obj.ParameterBP = val;
                obj.TrafficContributionsP = struct.empty;
            end
        end % function set.ParameterB(obj, val)
        
                
        function set.ParameterK(obj, val)
            if ~isequal(obj.ParameterKP, val)
                % Is a road network and model object specified?
                if ~isempty(obj.ParentRoadNetwork)
                    % A road network is.
                    if ~isempty(obj.ParentRoadNetwork.ModelObject)
                        % And a model object is too.
                        error('SRM1:RoadSegment:SetParameterK', 'The ParameterK property of this road segment is controlled by it''s parent SRM1Model object.')
                    end
                end
                obj.ParameterKP = val;
                obj.TrafficContributionsP = struct.empty;
            end
        end % function set.ParameterK(obj, val)
        
        %% Other functions.
        function ScaleVehicleCounts(obj)
            VCounts = obj.VehicleCounts;
            VBD = obj.VehicleBreakdown;
            for VI = 1:numel(VBD)
                Veh = VBD{VI};
                VCounts.(Veh) = VCounts.(Veh) * obj.VehicleScaling.(Veh);
            end
            obj.VehicleCountsScaledP = VCounts;
        end % function ScaleVehicleCounts(obj)
        
        function SetBoundingBox(obj)
            switch obj.RoadClass
                case 'Narrow Canyon'
                    DD = 30;
                case 'One Sided Canyon'
                    DD = 30;
                case 'Wide Canyon'
                    DD = 60;
                case 'Not A Canyon'
                    DD = 60;
                case 'NotSet'
                    DD = 0;
            end
            obj.ImpactDistanceP = DD;
            X = obj.Vertices(:, 1); Y = obj.Vertices(:, 2);
            BB = [min(X), min(Y); max(X), max(Y)];
            obj.BoundingBoxP = BB;
            obj.ImpactBoundingBoxP = BB + DD*[-1, -1; +1, +1];
        end % function SetBoundingBox(obj)
        
        function val = Emit_Single(obj, Pollutant, SpeedC)
            VCS = obj.VehicleCountsScaled;
            YearStr = sprintf('Y%04d', obj.EmissionFactorYear);
            EFS = obj.EmissionFactors.Factors.(YearStr).(Pollutant);
            EmVehs = obj.EmissionFactors.VehicleClasses;
            NumVehs = numel(obj.VehicleBreakdown);
            Ems = zeros(1, NumVehs);
            for Vi = 1:NumVehs
                Veh = obj.VehicleBreakdown{Vi};
                if isequal(SpeedC, 'Ignore')
                    Ems(Vi) = 0;
                elseif ismember(Veh, EmVehs)
                    Ems(Vi) = VCS.(Veh) * EFS.(Veh).(SpeedC);
                else
                    Ems(Vi) = 0;
                end
            end
            val = Ems;
        end % function val = Emit_Single(obj, Pollutant, SpeedC)
              
        function GetTrafficContributions(obj)
            DC = obj.DispersionCoefficients;
            D = obj.CalculationDistanceTotal;
            if D > obj.ImpactDistance
                [~, WID] = lastwarn;
                if ~isequal(WID, 'SRM1:RoadSegment:DistanceTooLarge')
                    warning('SRM1:RoadSegment:DistanceTooLarge', 'Distance is beyond impact distance for this road, so traffic contribution will be set to 0, but actually the traffic contribution is not defined at this distance. This warning will only be displayed once, but the event may be occuring repeatedly.')
                end
                TC.PM10 = 0; TC.PM25 = 0; TC.NOx = 0; TC.NO2 = 0;
                obj.TrafficContributionsP = TC;
                return
            elseif D < 30
                DispersionFactor = DC.A*D.^2 + DC.B*D + DC.C;
            elseif D < 60
                DispersionFactor = DC.Alpha*D^(-0.747);
            else 
                error('Don''t understand a Distance of %.*f.', DecPlaces(D), D)
            end
            FullFactor = 0.62*DispersionFactor.*obj.TreeFactor*5/obj.WindSpeed;
            Ems = obj.Emissions;
            
            TC.PM10 = FullFactor*Ems.PM10;
            TC.PM25 = FullFactor*Ems.PM25;
            TC.NOx = FullFactor*Ems.NOx;
            
            FNO = Ems.NO2/Ems.NOx;
            TC_NO2 = FNO*TC.NOx+obj.ParameterB*obj.BackgroundO3*(1-FNO)/(1-FNO+obj.ParameterK);
            if isnan(TC_NO2)
                TC.NO2 = 0;
            else
                TC.NO2 = TC_NO2;
            end
            obj.TrafficContributionsP = TC;
        end % function GetTrafficContributions(obj)
        
        function SetVehicleScaling(obj, varargin)
            VBD = obj.VehicleBreakdown;
            if numel(varargin) == 1
                if isnumeric(varargin{1})
                    % All the same value.
                    for VI = 1:numel(VBD)
                        V = VBD{VI};
                        VS.(V) = varargin{1};
                    end
                    obj.VehicleScaling = VS;
                elseif isstruct(varargin{1})
                    try
                        obj.VehicleScaling = varargin{1};
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
                            obj.VehicleScaling = VS;
                        else
                            rethrow(err)
                        end
                    end
                else
                    error('SRM1:RoadSegment:SetVehicleScalingF:SingleNotNumeric', 'If only one input is assigned for SetVehicleScaling, it sould either be a numeric scalar or an appropriate structure.')
                end
            else
                Options = checkArguments(obj.VehicleScaling, varargin);
                obj.VehicleScaling = Options;
            end
        end % function SetVehicleScaling(obj, varargin)

        function SetParentChangesMajor(obj)
            % A Major change will lead to RoadNetwork re-running the
            % functions that decide which road is relevent to each point,
            % and generating arrays of values used in the calculation of
            % concentration values. This process will require looping
            % through each calculation point, so it can be slow. This
            % should only be neccesary if the vertices are changed.
            if ~isempty(obj.ParentRoadNetwork)
                obj.TrafficContributionsP = struct.empty;
                obj.ParentRoadNetwork.ChangesMadeMajor = 1;
            end
        end % function SetParentChangesMajor(obj)

        function SetParentChangesMinor(obj, Field)
            if ~obj.Creating
                %obj.ParentRoadNetwork.ModelObject.RoadTrafficContributions.PM10(obj.RoadID)
                obj.TrafficContributionsP = struct.empty;
                %obj.ParentRoadNetwork.ModelObject.RoadTrafficContributions.PM10(obj.RoadID)
                if ~isempty(obj.ParentRoadNetwork)
                    obj.ParentRoadNetwork.ChangeValue({Field, obj.RoadID})
                end
                %obj.ParentRoadNetwork.ModelObject.RoadTrafficContributions.PM10(obj.RoadID)
            end
        end % function SetParentChangesMinor(obj)        
    end % methods
end % classdef RoadSegment < handle