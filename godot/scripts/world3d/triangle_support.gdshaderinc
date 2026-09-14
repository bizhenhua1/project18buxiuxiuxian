float triangle_support(vec2 xz){
 vec2 cell=floor(xz);vec2 f=xz-cell;
 if(f.x+f.y<=1.0){
  float a=ground_height(vec2(cell.x,-cell.y)*20.0);
  float b=ground_height(vec2(cell.x+1.0,-cell.y)*20.0);
  float c=ground_height(vec2(cell.x,-cell.y-1.0)*20.0);
  return a+(b-a)*f.x+(c-a)*f.y;
 }
 float a=ground_height(vec2(cell.x+1.0,-cell.y-1.0)*20.0);
 float b=ground_height(vec2(cell.x,-cell.y-1.0)*20.0);
 float c=ground_height(vec2(cell.x+1.0,-cell.y)*20.0);
 return a+(b-a)*(1.0-f.x)+(c-a)*(1.0-f.y);
}
