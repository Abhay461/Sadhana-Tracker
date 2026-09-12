import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { DailyQuote, DailyQuoteDocument } from '../database/schemas/daily_quotes.schema';
import { CreateDailyQuoteDto } from './dto/create-daily-quote.dto';

@Injectable()
export class DailyQuotesService {
  constructor(
    @InjectModel(DailyQuote.name) private readonly quoteModel: Model<DailyQuoteDocument>,
  ) {}

  async createQuote(user: any, dto: CreateDailyQuoteDto | any) {
    const today = new Date().toISOString().split('T')[0];
    
    let images: string[] = [];
    if (dto.imageUrls && Array.isArray(dto.imageUrls) && dto.imageUrls.length > 0) {
      images = dto.imageUrls;
    } else if (typeof dto.imageUrls === 'string' && dto.imageUrls.trim().length > 0) {
      images = [dto.imageUrls.trim()];
    } else if (dto.imageUrl && typeof dto.imageUrl === 'string' && dto.imageUrl.trim().length > 0) {
      images = [dto.imageUrl.trim()];
    }

    const quoteData: Record<string, any> = {
      date: dto.date || today,
      quote: dto.quote || '',
      author: dto.author || 'Srila Prabhupada',
      imageUrls: images,
      isActive: true,
    };

    if (user?._id) {
      quoteData.createdBy = user._id;
    }

    return this.quoteModel.create(quoteData);
  }

  async getTodayQuote() {
    const today = new Date().toISOString().split('T')[0];
    
    let quote = await this.quoteModel
      .findOne({ date: today, isActive: true })
      .sort({ createdAt: -1 })
      .exec();

    if (!quote) {
      quote = await this.quoteModel
        .findOne({ isActive: true })
        .sort({ createdAt: -1 })
        .exec();
    }

    return quote;
  }

  async getAllQuotes() {
    return this.quoteModel.find({ isActive: true }).sort({ createdAt: -1 }).limit(50).exec();
  }

  async deleteQuote(id: string) {
    return this.quoteModel.findByIdAndUpdate(id, { isActive: false }, { new: true });
  }
}
