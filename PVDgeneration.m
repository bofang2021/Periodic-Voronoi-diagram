%% Generates a periodic Voronoi diagram within a rectangular domain
%
% Author: Laurence Brassart
%
% The algorithm for periodic Voronoi diagram generation inspires from the
% following paper:
%
% Yan, D.M., Wang, K., L?vy, B., Alonso, L., 2011. "Computing 2D Periodic 
% Centroidal Voronoi tessallation", Proceedings of the Eight International
% Symposium on Voronoi diagrams in science and engineering. 
% DOI 10.1109/ISVD.2011.31
%
% Results are written as a list of nodes and list of edges for
% subsequent finite element analysis. Edges are connected by to nodes.
% 
% The script requires the mapping toolbox of Matlab
%
% 

clc;
close all
clear all

%Domain dimensions
Lx = 2;
Ly = 1;

N = 10;    % Number of sites in the domain 
A = Lx*Ly;  % Area       
R = sqrt((2*A)/(sqrt(3)*N));    % Reference length 
delta = 0.7;  % Degree of randomness   
s = R*delta;  % Minimum allowable distance between sites
d = 0.05*s;   % Minimum allowable distance between sites and edges 


%% STEP0: Generate N points randomly dispersed in the domain
cp=1;
att = 0;
maxAtt = 100000; %maximum number of attempts

X = zeros(N,1);
Y = zeros(N,1);

%initialise first point
X(1) = Lx*rand(1);
Y(1) = Ly*rand(1);

while (cp < N) 
     
    att = att + 1; 
     
    if att > maxAtt
        disp('could not position all the sites');
        disp('consider increasing maximum number of attempts and/or increasing tolerance on minimum distance')
        disp('try again!');
        
        return
    end
    
    %Trial point
    x = Lx*rand(1);
    y = Ly*rand(1);
    
    %Calculate distances from all other points
    D = sqrt((x-X(:)).^2 + (y-Y(:)).^2);
   
    % Only add the point if far enough
    if (all(D >= s) && (x>= d) && ((Lx-x) >= d) && (y >= d) && ((Ly-y) >= d))
        cp = cp + 1;
        X(cp)=x;
        Y(cp)=y;
        
    end
end

Points = [X Y];

%% STEP 1: Voronoi diagram construction 
%Create initial Delaunay triangulation
DT = delaunayTriangulation(X,Y);

figure(1)
triplot(DT,'r-');
hold on

%Create initial (non-periodic) Voronoi diagram
[V,R] = voronoiDiagram(DT);

voronoi(DT);
xlim([0 Lx]);
ylim([0 Ly]);
title('initial, non-periodic Voronoi diagram');

%% STEP 2: Boundary sites detection
% Find cells that have either an infinite vertex (unbounded cell) or cells
% that have vertices outside the box

BoundarySites = zeros(N,1);
cb = 0; %counter

%Loop on the Voronoi cells
for i=1:N
    
    %Loop on vertices of the cell
    vertices = R{i};    
    for j=1:length(vertices)
        
        v = vertices(j);
        
        %coordinates of the vertex
        x = V(v,1); y = V(v,2);
        
        %detect whether the vertex is infinite or outside the box
        if (v==1 || ~isinthebox(x,y,Lx,Ly))
            cb = cb + 1;
            
            %add the site to the list of boundary sites
            BoundarySites(cb) = i;
            break
        end
    end
end

%% STEP3: Periodic mirror insertion 
% Insert mirror points in all directions for all the boundary
% sites

mirrorPoints = zeros(8*cb,2);

%Loop on the boundary sites
for i=1:cb
    
    site = BoundarySites(i);
    x=Points(site,1);
    y=Points(site,2);

    m=0;
    for k=-1:1
        for l=-1:1
            if ~(k == 0 && l==0)
                m = m+1;
                xnew = x + k*Lx;
                ynew = y + l*Ly; 
                mirrorPoints(8*(i-1)+m,1) = xnew;
                mirrorPoints(8*(i-1)+m,2) = ynew;
            end
        end
    end    
end

%Create new Voronoi diagram adding the mirror points
%The new diagram is periodic over the initial domain
AllPoints = [Points;mirrorPoints]; 
Nall = length(AllPoints(:,1)); %total number of voronoi cells
DTbig = delaunayTriangulation(AllPoints(:,1),AllPoints(:,2));

figure(2)
triplot(DTbig,'r-');
hold on

%Create new Voronoi diagram
[Vbig,Rbig] = voronoiDiagram(DTbig);
maxVerNum = length(Vbig(:,1)); %maximum vertex number so far

voronoi(DTbig);
xlim([0 Lx])
ylim([0 Ly])
title('periodic triangulation and Voronoi')

%% STEP 4 - Calculate intersections of new Voronoi diagram with domain limits

%Gather all vertices and edges of the cells associated with sites inside
%the domain and which have at least one vertex in the box
Vertices = zeros(length(Vbig(:,1)),1);
Edges = zeros(length(Vbig(:,1)),2);
Xall = Vbig(:,1);
Yall = Vbig(:,2);
iv = 0;
ie = 0;
wrapN = @(x, n) (1 + mod(x-1, n));

%Loop over sites in the original domain + mirror sites
for i=1:Nall
     
    vlist = Rbig{i}; 
    nv = length(vlist);
        
    %loop over vertices of each cell
    for j=1:nv
     
        v1 = vlist(j);
        v2 = vlist(wrapN(j+1,nv));
        
        x1 = Xall(v1); y1 = Yall(v1);
        x2 = Xall(v2); y2 = Yall(v2);
               
        %only keep edges that have at least one vertex in the box 
        %and corresponding vertices
        if isinthebox(x1,y1,Lx,Ly) || isinthebox(x2,y2,Lx,Ly)
        
            ie = ie + 1;
            Edges(ie,:) = [v1, v2];

            iv = iv + 1;
            Vertices(iv) = v1;
            iv = iv + 1;
            Vertices(iv) = v2;

        end
    end
end

%remove zeros and duplicates
Vertices = unique(Vertices(1:iv)); %list of vertices for edges belonging to the domain

Es = sort(Edges(1:ie,:), 2); %sort rows of Edges in ascending order, removing zeros
Edges = unique(Es, 'rows'); %list of edges belonging to the domain

%find edge intersection with the boundary 
xbox = [0 Lx Lx 0 0];
ybox = [0 0 Ly Ly 0];

Vinter = [];
Xinter = [];
Yinter = [];
Vout = [];

counter = 0;

%Loop over the edges belonging to the domain
for i=1:length(Edges(:,1))
    
    v1 = Edges(i,1); v2 = Edges(i,2);
    x1 = Xall(v1); y1 = Yall(v1);
    x2 = Xall(v2); y2 = Yall(v2);

    %calculate intersection of the segment with the boundary
    [xi,yi] = polyxpoly([x1 x2],[y1 y2],xbox,ybox);
    
    %if the intersection with the boundary is not empty, then either v1 or
    %v2 is outside the box (not both)
    if ~isempty([xi,yi])
        
        counter = counter + 1;
        %case v1 is in the box: remove v2
        if isinthebox(x1,y1,Lx,Ly)
            k = 2;
            Vout(counter) = v2;
        %case v2 is in the box: remove v1
        else
            k = 1; 
            Vout(counter) = v1;
        end
        
        %add new vertex for the intersection
        newv = maxVerNum + counter;
        Vinter(counter) = newv;
        Xinter(counter) = xi;
        Yinter(counter) = yi;
        %modify edge connectivity
        Edges(i,k) = newv; 
                       
    end  
end

%Remove vertices outside the box
idx=ismember(Vertices,Vout);
Vertices(idx) = [];


%add new vertices and coordinates of intersection points to the list
%number of edges is unchanged
Vertices = [Vertices;Vinter'];
Xall = [Xall;Xinter'];
Yall = [Yall;Yinter'];


%Remove short edges
short_edges = [];
counter = 0;

for i=1:length(Edges(:,1))
    
    v1 = Edges(i,1); v2 = Edges(i,2); 
    x1 = Xall(v1); y1 = Yall(v1); 
    x2 = Xall(v2); y2 = Yall(v2); 
    
    %check the edge length
    dist = sqrt((x1-x2)^2 + (y1-y2)^2);
    
    %if edge is too small, then merge the two vertices
    if dist < 0.05*Lx 
        
        Xall(v2) = Xall(v1); 
        Yall(v2) = Yall(v1); 
        Vertices(find(v2)) = v1;
        
        counter = counter + 1;
        short_edges(counter) = i;   %list of short edges to be removed
    end
end

%remove short edges from the list
Edges(short_edges,:) = [];
%remove duplicate vertices due to merging
Vertices = unique(Vertices);

%% STEP 5: create nodes and edges 

Nedges = length(Edges(:,1));
Nvertices = length(Vertices); 

Nnodes = Nvertices;
Nedgenode = 2;
        
GeometryNodes = zeros(Nnodes,3);
GeometryEdges = zeros(Nedges,Nedgenode+1);

%loop over the existing vertices
for i=1:Nvertices
   
    n = Vertices(i);
    x = Xall(n);
    y = Yall(n);
    
    GeometryNodes(i,:) = [n,x,y];

end

maxVerNum = max(Vertices); %maximum vertex number so far
nodeCounter = Nvertices;
edgeCounter = 0;

%loop over the segments
for i=1:Nedges
    
    n1 = Edges(i,1); n2 = Edges(i,2); 
    x1 = Xall(n1); y1 = Yall(n1); 
    x2 = Xall(n2); y2 = Yall(n2); 
    
    nodeCounter = nodeCounter + 1;
    edgeCounter = edgeCounter + 1;
    
    GeometryEdges(edgeCounter,:) = [i,n1,n2]; 
end

%sort nodes by ascending number
GeometryNodes = sortrows(GeometryNodes,1);

%write mesh in text file
fid = fopen('geometry-nodes.txt','w');
for i=1:length(GeometryNodes)
    fprintf(fid,'%d\t %.6f\t %.6f\n',GeometryNodes(i,1),GeometryNodes(i,2),GeometryNodes(i,3));
end
fclose(fid);

fid = fopen('geometry-edges.txt','w');
for i=1:length(GeometryEdges)
    fprintf(fid,'%d\t',GeometryEdges(i,1));
    for j=1:Nedgenode
        fprintf(fid,'%d\t',GeometryEdges(i,j+1));
    end
    fprintf(fid,'\n');

end
fclose(fid);
    

 

    
    
    
