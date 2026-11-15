import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config';
import { requireAuth } from './auth';
import { requestId, errorHandler } from './errors';
import { router } from './routes';

const app=express();
app.use(helmet());
app.use(cors({origin:config.CORS_ORIGIN.split(',').map(x=>x.trim()),credentials:true}));
app.use(express.json({limit:'256kb'}));
app.use(requestId);
app.get('/health',(_req,res)=>res.json({status:'ok',service:'volopay-backend',version:'0.3.0'}));
app.use('/v1/workspaces/:workspaceId', (req,res,next)=>{
  // URL workspaceId is a selector only. Auth middleware checks current membership.
  req.headers['x-workspace-context']=req.params.workspaceId;
  next();
}, requireAuth, router);
app.use(errorHandler);
app.listen(config.PORT,()=>console.log(`Volopay API listening on ${config.PORT}`));
