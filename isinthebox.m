 function inflag = isinthebox(x,y,Lx,Ly)
    %Returns True if the point is within the domain boundaries
 
    inflag = true;
    if ((x < 0) || (x > Lx) || (y < 0) || (y > Ly))
        inflag = false;
    end
        
 end