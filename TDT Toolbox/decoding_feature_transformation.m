% function [cfg,trans_results,data_train_trans,data_test_trans] = decoding_transform_features(cfg,data_train,data_test)
% 
% This function transforms features of decoding data and is an integral 
% part of the decoding toolbox. This function is called from decoding.m 
% and should not be called directly. Feature transformation entails
% methods that apply transformations of feature space (e.g. rotations as 
% is the case for PCA). These methods can be used for feature selection, 
% as well. In this toolbox, they are kept separate, because transformation
% methods are also used for other purposes. This additionally facilitates
% the use of multi-step feature selection methods. Feature transformation
% is done on training data and then applied to test data.
%
% INPUT
% cfg: structure passed from decoding.m with at least the following fields:
%   feature_transformation: struct containing feature transformation parameters
%   fields:
%       method:          Method of feature transformation that should be
%                        carried out. Implemented methods start with
%                        transfeat_ , following the method that is entered
%                        here. Currently, only 'PCA' is implemented (thus
%                        the function is called transfeat_PCA). If you
%                        wish to implement your own method, adapt your
%                        function to the input-output-structure of
%                        transfeat_PCA.
%
%       estimation:      'all', 'across' or 'none'. When all is selected,
%                        the transformation of features is estimated and
%                        applied to all data. When across is selected, the
%                        transformation is estimated on each step on
%                        training data only, and then applied to both
%                        training and test data separately (slower).
%                        If 'all' is selected, it is the responsibility of
%                        the user to make sure that data transformation
%                        does not lead to double dipping, i.e.
%                        non-independence of training and test data.
%
%       n_vox:           Number of top-ranked features (e.g. voxels) to 
%                        keep after transformation (optional input). Input 
%                        can either be integer values >=1, percentage 
%                        values as values < 1, or the string 'all' to 
%                        carry out no selection.
%
%       critical_value:  Alternative method that determines a number
%                        n_vox that may vary from iteration to
%                        iteration. A critical value can be entered that 
%                        needs to be exceeded in the score generated by 
%                        the method (e.g. percent variance explained for
%                        PCA).
%
%       scale:           Scaling of features. Can be useful depending on
%                        the method used (e.g. for PCA). Follows same
%                        mechanism of action as cfg.scale (see main
%                        function decoding.m)
%
%   data_train: training data (for estimation = 'across') or all data (for
%       estimation = 'all')
%   data_test: testing data (required input for estimation = 'across')
%
% OUTPUT
% cfg: possibly adapted input cfg
% trans_results: Results that are passed to results matrix
% data_train_trans: Transformed training data
% data_test_trans: Transformed testing data
%
% 2014/01/12 Martin Hebart
%
% See also DECODING, DECODING_DEFAULTS, DECODING_SCALE_DATA,
% DECODING_FEATURE_SELECTION, DECODING_PARAMETER_SELECTION

function [cfg,data_train_trans,data_test_trans] = decoding_feature_transformation(cfg,data_train,data_test)

method = cfg.feature_transformation.method;
estimation = cfg.feature_transformation.estimation;

if strcmpi(estimation,'across')
    train_length = size(data_train,1);
    scaled = decoding_scale_data(cfg.feature_transformation,[data_train; data_test]); % because training data are balanced, currently the default for scaling is 'all' or 'none'
    data_train = scaled(1:train_length,:);
    data_test = scaled(train_length+1:end,:);
elseif strcmpi(estimation,'all')
    data_train = decoding_scale_data(cfg.feature_transformation,data_train);
    % create dummy variable
    data_test = zeros(size(data_train));
end



%% Transform data

if ischar(method)
    fhandle = str2func(['transfeat_' method]);
    [cfg,data_train_trans,data_test_trans,score] = feval(fhandle,cfg,data_train,data_test);
    % e.g. if method = 'yourmethod', this calls:
    % [cfg,data_train_trans,data_test_trans,score] = transfeat_yourmethod(cfg,data_train,data_test);   
elseif isobject(method)
    % use passed handle directly and return
    [cfg,data_train_trans,data_test_trans,score] = method.apply(cfg,data_train,data_test);
    
else
    error('Dont know how to handle method %s', method)
    
end

%% If requested, select subset of transformed data

if isfield(cfg.feature_transformation,'n_vox')
    n_vox = cfg.feature_transformation.n_vox;
   if ischar(n_vox)
       if strcmpi(n_vox,'all')
           return % do nothing and return
       else
           error('Unknown method %s field for cfg.feature_transformation.n_vox)',n_vox)
       end
   elseif n_vox < 1 % selection in percent
        n_vox = ceil(n_vox * size(data_train,2));
   elseif n_vox > size(data_train,2)
       warningv('DECODING_FEATURE_TRANSFORMATION:MAXIMAL_N_VOX_EXCEEDED',...
           'cfg.feature_transformation.n_vox has been selected to be larger than the number of available features. Setting to maximum and doing no selection')
   end
   
   [ignore,score_ind] = sort(score,'descend'); %#ok<ASGLU>
   score_ind = score_ind(1:n_vox);
   
   data_train_trans = data_train_trans(:,score_ind);
   data_test_trans = data_test_trans(:,score_ind);
end

if isfield(cfg.feature_transformation,'critical_value')
    score_ind = score > cfg.feature_transformation.critical_value;
    if all(score_ind)
        warningv('DECODING_FEATURE_TRANSFORMATION:ALL_SCORES_LARGER',...
            'All scores selected are larger than the critical value provided in cfg.feature_transformation, so no selection is performed.')
        return
    end
    data_train_trans = data_train_trans(:,score_ind);
    data_test_trans = data_test_trans(:,score_ind);
end
    
