function [ desired_state ] = traj_generator(t, state, waypoints)
% TRAJ_GENERATOR: Generate the trajectory passing through all
% positions listed in the waypoints list
%
% NOTE: This function would be called with variable number of input arguments.
% During initialization, it will be called with arguments
% trajectory_generator([], [], waypoints) and later, while testing, it will be
% called with only t and state as arguments, so your code should be able to
% handle that. This can be done by checking the number of arguments to the
% function using the "nargin" variable, check the MATLAB documentation for more
% information.
%
% t,state: time and current state (same variable as "state" in controller)
% that you may use for computing desired_state
%
% waypoints: The 3xP matrix listing all the points you much visited in order
% along the generated trajectory
%
% desired_state: Contains all the information that is passed to the
% controller for generating inputs for the quadrotor
%
% It is suggested to use "persistent" variables to store the waypoints during
% the initialization call of trajectory_generator.


%% Example code:
% Note that this is an example of naive trajectory generator that simply moves
% the quadrotor along a stright line between each pair of consecutive waypoints
% using a constant velocity of 0.5 m/s. Note that this is only a sample, and you
% should write your own trajectory generator for the submission.

% persistent waypoints0 traj_time d0
% if nargin > 2
%     d = waypoints(:,2:end) - waypoints(:,1:end-1);
%     d0 = 2 * sqrt(d(1,:).^2 + d(2,:).^2 + d(3,:).^2);
%     traj_time = [0, cumsum(d0)];
%     waypoints0 = waypoints;
% else
%     if(t > traj_time(end))
%         t = traj_time(end);
%     end
%     t_index = find(traj_time >= t,1);
% 
%     if(t_index > 1)
%         t = t - traj_time(t_index-1);
%     end
%     if(t == 0)
%         desired_state.pos = waypoints0(:,1);
%     else
%         scale = t/d0(t_index-1);
%         desired_state.pos = (1 - scale) * waypoints0(:,t_index-1) + scale * waypoints0(:,t_index);
%     end
%     desired_state.vel = zeros(3,1);
%     desired_state.acc = zeros(3,1);
%     desired_state.yaw = 0;
%     desired_state.yawdot = 0;
% end
%


%% Fill in your code here


persistent waypoints0 traj_time d0 COEFS
 
if nargin > 2
    
        d = waypoints(:,2:end) - waypoints(:,1:end-1);
        d0 = 2 * sqrt(d(1,:).^2 + d(2,:).^2 + d(3,:).^2);
        traj_time = [0, cumsum(d0)];
       
        waypoints0 = waypoints; 
        
        n = size(waypoints, 2)-1;
        A = zeros(8*n, 8*n);
        b = zeros(8*n, 3);
        
                
        % Prepare coefficients of polynomial (order 8) derivatives  
        %   p(t) = t^7 + t^6 + ... + 1  
                % --> coefs = [ 1 1 1 ... 1 ]
        %   pdot(t) = a1*t^6 + a2*t^5 + ... 
                % --> coefs = [ 7 6 ... 0(padded with 0) ]
                
        % poly_coefs(1,:) = p
        % poly_coefs(2,:) = pdot
        % ...
 
        poly_n = 8;
        poly_k_max = 6; %  6th derivative 
        poly_coefs = zeros(poly_k_max + 1, poly_n);
        poly_coefs(1, :) = ones(1, poly_n);
        for i=2:poly_k_max+1
            poly_coefs(i, :) = [ polyder(poly_coefs(i-1, 1:poly_n-(i-2))) zeros(1, i-1)];
        end
       

        %% Boundary conditions
        row_index = 1; % each BC corresponds to one row
        
        % Points wi belong to the trajectory
        for i=1:n
            % p(t=0) = w(i-1)
            A(row_index, 8*(i-1)+8) = 1;
            b(row_index, :) = waypoints0(:, i)'; 
            row_index = row_index + 1;
        
            % p(t=1) = wi
            A(row_index, 8*(i-1)+1:8*i) = poly_coefs(1, :);
            b(row_index, :) = waypoints0(:, i+1);
            row_index = row_index + 1;
        end
        
        % Start & end velocities = 0 
        % pdot(0) = 0
        A(row_index, 7) = 1;
        row_index = row_index + 1;

        
        % pdot(1) = 0
        i = n;
        A(row_index, 8*(i-1)+1:8*i) = poly_coefs(2, :);
        row_index = row_index + 1;
       
       
        % Start & end accelerations = 0 
        % pdot2(0) = 0
        A(row_index, 6) = 1;
        row_index = row_index + 1;
        
        
        % pdot2(1) = 0
        i = n;
        A(row_index, 8*(i-1)+1:8*i) = poly_coefs(3, :);
        row_index = row_index + 1;
        
        
        % Start & end jerks = 0 
        % pdot3(0) = 0
        A(row_index, 5) = 1;
        row_index = row_index + 1;

        % pdot3(1) = 0
        i = n;
        A(row_index, 8*(i-1)+1:8*i) = poly_coefs(4, :);
        row_index = row_index +1;
       
        % Derivatives 1-6th are continuous
        for i=1:n-1
            for k=1:6
                A(row_index, 8*(i-1)+1:8*i) = poly_coefs(k+1, :);
                A(row_index, 8*(i)+(8-k)) = -poly_coefs(k+1, poly_n - k);
                row_index = row_index + 1;
            end
        end 
        
        %% Solve and save
        C = A\b;
        
        COEFS = struct;
        COEFS.pos = zeros(n,3,8); % [n = segment no, axis, coef i]
        COEFS.vel = zeros(n,3,7);
        COEFS.acc = zeros(n,3,6);
        
        for i=1:n
            segment_coefs = C(8*(i-1)+1:8*i,:);
            
            COEFS.pos(i,:,:) = segment_coefs';
            for axis=1:3
                COEFS.vel(i,axis,:) = polyder(COEFS.pos(i,axis,:));
                COEFS.acc(i,axis,:) = polyder(COEFS.vel(i,axis,:));
            end
        end
        

else
      
        desired_state.pos = zeros(3,1);
        desired_state.vel = zeros(3,1);
        desired_state.acc = zeros(3,1);
        desired_state.yaw = 0;
        desired_state.yawdot = 0;
        
        if(t > traj_time(end))
            t = traj_time(end);
        end
        t_index = find(traj_time >= t,1);

        if(t_index > 1)
            t = t - traj_time(t_index-1);
        end
        if(t == 0)
            desired_state.pos = waypoints0(:,1);
        else
            scale = t/d0(t_index-1);
            
            for axis=1:3
                desired_state.pos(axis) = polyval(squeeze(COEFS.pos(t_index-1, axis, :)), scale);
                desired_state.vel(axis) = polyval(squeeze(COEFS.vel(t_index-1, axis, :)), scale).*(1/d0(t_index-1));
                desired_state.acc(axis) = polyval(squeeze(COEFS.acc(t_index-1, axis, :)), scale).*(1/d0(t_index-1)^2);
            end

        end


end

end

