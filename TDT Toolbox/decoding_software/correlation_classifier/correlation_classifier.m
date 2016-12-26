% function [predicted_labels,decision_values,opt] = correlation_classifier(labels_test,data_test,model)
%
% This function uses a Haxby style MVPA analysis where multivoxel patterns
% *within* one class are simply correlated and tested against another 
% correlation *between* the same and a different classes. The pattern is 
% said to carry information about the category if the within class 
% correlation is consistently higher than the between class correlation. 
% The output predicted_labels is the prediction that is generated by the 
% larger correlation coefficient. The output decision_values is the
% z_transformed correlation difference generated by the within and between
% correlation comparison (for details, see content of this function).
%
% For more than two classes, the most positive correlation receives the
% class label. In other words, the classifier is by definition a one-vs-one
% classifier. The decision values are set up pairwise accordingly.
%
% 2009 Martin H.

% History:
% 2015-11-25 Kai (thanks to Carlo):
%   Removed bug in correlation_classifier that prediction was done using 
%   unique_labels_test instead of unique_labels_train
% 2015-03-02 Martin:
% - retain original sorting of labels
% 2014-01-19 Martin:
% - made compatible with multiple classes
% - enabled passing more output

% Typical structure of MVPA:
% 1. Split-half of two data sets (in general split n possible)
% 2. First half of label 1 correlated with second half of label 1, 
%    first half of label 2 correlated with second half of label 2
% 3. First half of label 1 correlated with second half of label 2,
%    first half of label 2 correlated with second half of label 1
% 4. Comparison of these two correlations
% 5. Classification: For which label is the correlation more positive?

% for two-class classification the decision values are
% within_class_correlation - between_class_correlation
% for thee classes:
% (train 1, test 1) (train 2 test 1), (train 3 test 2)
% etc for more classes. Since all use the same model, the maximal
% correlation always wins

function [predicted_labels,decision_values,opt] = correlation_classifier(labels_test,data_test,model)

% Output correlation matrix: columns are train indices, rows are test indices.
% TODO: also pass unique labels to know what columns and rows are referred
% to
%

% unpack
data_train = model.data_train;
labels_train = model.labels_train;

unique_labels_train = uniqueq(labels_train); % sorts labels!
unique_labels_test = uniqueq(labels_test); % sorts labels!

n_labels_train = size(unique_labels_train,1);
n_labels_test = size(unique_labels_test,1);
[n_samples_train,n_vox] = size(data_train);
n_samples_test = size(data_test,1);

% If multiple instances of training and test vectors are present, combine
% them together (create a different classifier if you want to keep them
% separate)
train = zeros(n_vox,n_labels_train);
for i_label = 1:n_labels_train
    train(:,i_label) = sum(data_train(labels_train==unique_labels_train(i_label),:),1);
end
test = zeros(n_vox,n_labels_test);
for i_label = 1:n_labels_test
    test(:,i_label) = sum(data_test(labels_test==unique_labels_test(i_label),:),1);
end

if n_samples_train ~= n_samples_test % only in this case we need to normalize
    train = train/n_samples_train;
    test = test/n_samples_test;
end
    
if n_vox > 1 % normal case in which more than one voxel is present
    
    % create correlation matrix
    r = correlmat(test,train);
    r2 = correlmat([train(:,1); test(:,1)], [train(:,2); test(:,2)]);
    
    if r2 == 1
        r2 = correlmat(train(:,1), test(:,2));
    end
    
    % force finite values for later z-transformation
    r1 = (abs(r)+eps)>=1; % eps corrects for rounding errors in r
    if any(r1(:))
        warning('CORRELATION_CLASSIFIER:ZCORRINF','Correlations of +1 or -1 found. Correcting to +/-0.99999 to avoid infinity for z-transformed correlations!')
        r(r1) = 0.99999*r(r1); % forces finite values
    end
    
    % translate to Fisher's z transformed values for decision-values
    z = atanh(r);

    % these are not the same as decision values, but they give a useful distance metric from the classification boundary
    g = nchoosek(1:n_labels_train,2);
    decision_values = z(:,g(:,1))-z(:,g(:,2));
    [ignore,predict_ind] = max(z,[],2); %#ok<ASGLU>
    predicted_labels = unique_labels_train(predict_ind);

    opt.r = r2;
    opt.z = z;

else % if only one voxel is present, a correlation is not possible
   
warning('CORRELATION_CLASSIFIER:ONEVOXEL','Searchlight or ROI with only one voxel (may happen at borders of mask). No correlation possible, setting value to NaN!')

opt.r = NaN(n_labels_test,n_labels_train);
opt.z = NaN(n_labels_test,n_labels_train);
decision_values = NaN(n_labels_test,nchoosek(n_labels_train,2));
predicted_labels = NaN(n_labels_test,1);

end