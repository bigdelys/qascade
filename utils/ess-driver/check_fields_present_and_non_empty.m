function [issues, fineFields, missingFields, emptyFields] = check_fields_present_and_non_empty(s, requiredFields, file, issues, textPart)

fieldNames = fieldnames(s);
missingFields = setdiff(requiredFields, fieldNames);

if ~isempty(missingFields)
    if isempty(file)
        issues.addError(sprintf(['Missing these fields from ' textPart ' :\n   %s\n'], strjoin_adjoiner_first(', ', missingFields)));
    else
        issues.addError(sprintf(['Missing these fields from ' textPart ' of file ''%s'':\n   %s\n'], file, strjoin_adjoiner_first(', ', missingFields)));
    end;
end;

emptyFields = {};
for k=1:length(fieldNames)
    if isempty(s.(fieldNames{k}))
        emptyFields{end+1} = fieldNames{k};
    end;
end;

emptyButRequiredFields = intersect(requiredFields, emptyFields);

if ~isempty(emptyButRequiredFields)
    if isempty(file)
        issues.addError(sprintf(['These fields are required, defined, but empty in ' textPart ' :\n   %s\n'], strjoin_adjoiner_first(', ', emptyButRequiredFields)));
        
    else
        issues.addError(sprintf(['These fields are required, defined, but empty in ' textPart ' of file ''%s'':\n   %s\n'], file, strjoin_adjoiner_first(', ', emptyButRequiredFields)));
    end;
end;

fineFields = setdiff(fieldNames, [missingFields emptyFields]);