
%find the images
f = dir('*.jpg');
files = {f.name};

out = zeros(numel(files), 5);

%do calculations for each hand image
for j = 1:numel(files)
    %get one of the images
    img = imread(files{j});

    %the images were pretty big and taking a while so i scaled them
    img = imresize(img, .5);

    %convert the image to greyscale
    img = rgb2gray(img);
    %blur the image
    img = imgaussfilt(img, 8);
    %use kmeans to seperate the image into background and not backgrond
    img = imsegkmeans(img, 2);
    %subtract 1 from all values to make it boolean
    img = img - 1;

    %get the skeleton of the boolean image
    skel = uint8(bwmorph(img, 'skel', Inf));

    %remove the skeleton from the original image so the branches are visible
    skelitonized = img - skel;

    %this figure will be used for output through out
    imshow(skelitonized , []);

    %store the start to all the branches in the image
    branches = bwmorph(skel, 'branchpoints');

    hold all;

    %convert the branches to points
    [y, x] = find(branches);
    plot(x, y, 'ro');

    %assume that the lowest 4 y values are finger tips
    y_sorted = sort(y, 'ascend');

    %we are ignoring the thumb
    %find the points indicating finger tips
    fingers = 4;
    finger_tips = zeros(fingers, 2);

    %output is width of 4 fingers plus the palm
    output_vector = zeros(fingers + 1, 1);

    %find the corresponding point to y_sorted in x
    for i = 1:fingers
       x_index = find(y == y_sorted(i));
       finger_tips(i, 1) = x(x_index);
       finger_tips(i, 2) = y_sorted(i);
    end

    %plot the finger tips in blue
    scatter(finger_tips(:, 1), finger_tips(:, 2), 'b');

    %Find an axis to use for the palm part of the vector. Also to pin point the
    %orthogonal lines to the palm that indicate the fingers for the next step.
    %Take the lowest finger tip as the horizontal axis. Move down that axis
    %until a block of pixels is found that is uninterrupted by background
    %pixels and assume this is the palm. We will use this axis as one of the
    %vectors.
    palm_y = max(finger_tips(:, 2));
    keepGoing = true(1);

    [~, width] = size(img);

    while keepGoing
       %get the current row that is being considered from the original non
       %skeletonized image
       row = img(palm_y, :);
       left = 1;
       right = width;

       %find the left bound
       for i = 1:width
          if row(i) == 1
              left = i;
              break;
          end
       end

       %find the right bound 
       for i = left:width
          if row(i) == 0
              right = i;
              break;
          end
       end

       %if a 1 appears after the right bound we need to loop again
       for i = right:width
           if row(i) == 1
               keepGoing = true(1);
               palm_y = palm_y + 1;
               break;
           elseif i == width
               keepGoing = false(1);
           end
       end
    end

    output_vector(1) = right - 1 - left;

    %Now we need to find where the skeletonization matches up with the
    %identified finger tips along the palm axis in order to generate the 
    %normal lines that will be our axis for measuring the fingers. We can do
    %this as the skeletonization assures us that the branches are 1px wide.
    palm_branch_base = zeros(fingers, 2);
    skeletal_palm_row = skelitonized(palm_y, :);

    base = 1;
    for i = left:right - 1
       if skeletal_palm_row(i) == 0
          palm_branch_base(base, 1) =  i;
          palm_branch_base(base, 2) = palm_y;
          base = base + 1;
       end
    end

    scatter(palm_branch_base(:, 1), palm_branch_base(:, 2), 'm');

    %With the branch start and base on the palm now found we need to find the
    %midpoint between the start and base of the branches

    %The finger tips need to be rearranged to be sorted left to right as currently
    %they are sorted by height. The palm points are already left to right.
    finger_tips = sortrows(finger_tips, 1);

    midpoints = zeros(fingers, 2);
    spread = 120;

    for i = 1:fingers

       % get the mid points
       x1 = finger_tips(i, 1);
       y1 = finger_tips(i, 2);
       x2 = palm_branch_base(i, 1);
       y2 = palm_branch_base(i, 2);
       midpoints(i, 1) = floor((x1 + x2) / 2);
       midpoints(i, 2) = floor((y1 + y2) / 2);

       %get the linear regression line
       [p, ~] = polyfit([x1, x2], [y1, y2], 1);
       %get the slope of the normal line
       slope = -1 / p(1);
       %get b
       b = midpoints(i, 2) - midpoints(i, 1) * slope;

       %the range of x for the axis
       x = midpoints(i,1)-spread:midpoints(i,1)+spread;

       norm_line = slope*x + b;

       %plot the normal lines for visualization
       plot(x, norm_line, 'r-.');

       %store the end points
       end_x = [midpoints(i,1)-spread, midpoints(i,1)+spread];
       end_y = [slope * (midpoints(i,1)-spread) + b, slope * (midpoints(i,1)+spread) + b];

       %plot the end points for visualization
       scatter(end_x(1), end_y(1), 'y');
       scatter(end_x(2), end_y(2), 'y');

       %get the pixels along the axis for the finger
       [pixels] = improfile(img, end_x, end_y, spread * 2);

       output_vector(i + 1) = sum(pixels(:) == 1);
    end
    
    scatter(midpoints(:, 1), midpoints(:, 2), 'g');
    
    %record this iterations results
    out(j, :) = output_vector;
end

thresholds = [1, .30, .20, .15, .10, .05, .02, .01, .005];

[~, n] = size(thresholds);

%use the 4th row as the reference value
%reference = out(4, :);

for j = 1:n
    positives = 0;
    for i =1:size(out)
        %we used 4 as the true value don't use this caluclation for it
        if i ~= 4
            dif = abs(mean( (out(i, :) - reference) ./ reference ));
            if dif < thresholds(j)
                positives = positives + 1;
            end
        end
    end
    disp(thresholds(j));
    disp(positives);
end

