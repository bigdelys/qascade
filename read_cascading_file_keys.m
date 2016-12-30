function filekeys = read_cascading_file_keys(folder, parentKeys, fileMatcheDirectives, rootFolder)
filekeys = containers.Map;

if exist('parentKeys', 'var')
    folderKeys = parentKeys;
else
    folderKeys = containers.Map;
end;

if ~exist('fileMatcheDirectives', 'var')
    fileMatcheDirectives = containers.Map;
end;

% make sure that folder variable does not have a file separator (since we do not want double file
% separators anywhere)
if folder(end) == filesep
    folder = folder(1:(end-1));
end;

if ~exist('rootFolder', 'var')
    rootFolder = folder;
end;

manifestFileName = 'manifest.cfk.yaml';
matchDirective = 'matches';
tableDirective = 'table';
noSubfolderDirective = 'no-subdir';

% get the list of files and folders
d = dir(folder);
d(1:2) = [];
names = {d.name};
subfolderMask = [d.isdir];

subfolders = names(subfolderMask);
files = names(~subfolderMask);

onlyThisFolderKeys = containers.Map;

% look for the manifest file in the folderm exlude it from the list of files, and process it.
id = strcmp(files, manifestFileName);
if any(id)
    files(id) = []; % remove the manifest from the list of payload files.
    newFolderKeys = ReadYamlRawMap([folder filesep manifestFileName]);
    
    % overwrite keys
    keys = newFolderKeys.keys;
    
    for i = 1:length(keys)
        if ~isempty(regexp(keys{i}, ['^(' matchDirective '.*\)$'], 'once')) %  ^ in the beginning indices that it has to start with [, $ indicates that it has to end with ]
            matchPattern = keys{i}((length(matchDirective)+3):(end-1));
            if isKey(fileMatcheDirectives, matchPattern)
                fileMatcheDirectives(matchPattern) = [fileMatcheDirectives(matchPattern); newFolderKeys(keys{i})];
            else
                fileMatcheDirectives(matchPattern) = newFolderKeys(keys{i});
            end;
        elseif ~isempty(regexp(keys{i}, ['^(' tableDirective '.*\)$'], 'once')) %  ^ in the beginning indices that it has to start with [, $ indicates that it has to end with ]
            % table name is not important
            
            % write to a temporary file and use readtable to import as tsv file
            tempFileName = [tempname '.txt'];
            fid = fopen(tempFileName, 'w');
            fprintf(fid, newFolderKeys(keys{i}));
            fclose(fid);
            
            tble = readtable(tempFileName,'Delimiter','\t','ReadVariableNames',true);
            delete(tempFileName);
            
            if strcmp(tble.Properties.VariableDescriptions{1}, 'Original column heading: ''<matches>''')  % strcmp(tble.VariableNames{1}, 'x_matches_')
                for j=1:height(tble)
                    map = containers.Map;
                    for k=2:width(tble) % extract key:value pairs from the tabel, into a map,then assign that map to the match pattern in fileMatcheDirectives.
                        map(tble.Properties.VariableNames{k}) = tble{j,k};
                    end;
                    matchPattern = cell2mat(tble{j, 'x_matches_'});
                    if isKey(fileMatcheDirectives, matchPattern)
                        fileMatcheDirectives(matchPattern) = [fileMatcheDirectives(matchPattern); map];
                    else
                        fileMatcheDirectives(matchPattern) = map;
                    end;
                    
                end;
            else
                error('The the table specified in %s does not have (matches) as its first column header', keys{i});
            end
        elseif ~isempty(regexp(keys{i}, ['^(' noSubfolderDirective '.*\)$'], 'once')) %  ^ in the beginning indices that it has to start with [, $ indicates that it has to end with ]
            onlyThisFolderKeys = [onlyThisFolderKeys; newFolderKeys(keys{i})];
        else
            folderKeys(keys{i}) = newFolderKeys(keys{i});
        end;
    end
end;

% add file keys for the current folder
for i=1:length(files)
    filekeys([folder filesep files{i}]) = [folderKeys; onlyThisFolderKeys];
end;


% apply file match directives (overwrite keys for files matching certain wildcard expressions)
keys = fileMatcheDirectives.keys;
for i=1:length(keys)
    
    % create full paths but exclude the root folder so it is not used in pattern matching (this
    % makes it portable)
    fullPaths = strcat([folder((length(rootFolder)+1):end) filesep], files);
    
    matchIds = find(~cellfun(@isempty, regexp(fullPaths, regexptranslate('wildcard', keys{i})))); % math the full file path, including the name. This alows
    
    % overwrite keys when a file name matched wildcard
    for j=1:length(matchIds)
        filekeys([folder filesep files{matchIds(j)}]) = [filekeys([folder filesep files{j}]); fileMatcheDirectives(keys{i})];
    end;
    
end;

% add file keys for the subfolder
for i=1:length(subfolders)
    % this is because container.Map is a handle class, hence
    % sending it inside a function can change its value
    folderKeysContainer = containers.Map(folderKeys.keys, folderKeys.values);
    
    newFileKeys = read_cascading_file_keys([folder filesep subfolders{i}], folderKeysContainer, fileMatcheDirectives, rootFolder);
    filekeys = [filekeys; newFileKeys];
end;
end